classdef QLabs
    %QLabs Download, install, and launch Quanser Interactive Labs
    %   A set of functions to make it easy to get and use Quanser Interactive Labs.
    %
    %   * Type QLabs.install to download and install.  
    %   * Type QLabs.register to go to the Quanser registration page.
    %   * Type QLabs.launch to launch the Quanser Interactive Labs.
    
    properties(Hidden, Constant)
        % Registration portal information
        RegistrationHost = "www.quanser.com";
        RegistrationPath = "mathworks-qlabs-trial";

        % Installer download information
        DownloadHost = "quanserinc.box.com";
        DownloadPath = "shared/static";
        ZipFileName = "lhf0gilgy1zu5hedkokb9mi025gzcu19.zip";
        InstallerFileName = "Install QLabs.exe";

        %Installed Application info
        QLabInstalledRegistrationSubKey = "SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UpgradeCodes\8846B7B58AF54674387D6C27459B5088";
        QLabFileName = "Quanser Interactive Labs.exe";
        QLabFilePathInProgramFiles = ["Quanser","Quanser Interactive Labs"];
        DownloadDir = tempdir;
    end
    
    methods(Static, Access = public)
        function download()
            % download Download the installer for Quanser Interactive Labs

            QLabs.errorIfPlatformInvalid;
            if QLabs.isInstalled()
                % It's already installed,  don't install again.
                return
            end

            if ~QLabs.isZipPresent() && ~QLabs.isInstallerPresent()
                % Only download if ZIP isn't downloaded, the install
                % EXE isn't present

                % Get the URI for the ZIP file to download
                zipFileURI = QLabs.createSecureURI(QLabs.DownloadHost, QLabs.DownloadPath, QLabs.ZipFileName);

                % Set up the HTTP get request and handler for file read
                request = matlab.net.http.RequestMessage(matlab.net.http.RequestMethod.GET);
                zipFilePath = fullfile(QLabs.DownloadDir,QLabs.ZipFileName);
                consumer = matlab.net.http.io.FileConsumer(zipFilePath);

                % Set up callback for download progress indicator
                opt = matlab.net.http.HTTPOptions(...
                    'ProgressMonitorFcn',@QLabsDownloadProgress,...
                    'UseProgressMonitor',true);
                try
                    % Send the HTTP request
                    httpResponse = request.send(zipFileURI,opt,consumer);
                catch e
                    if QLabs.isZipPresent()
                        delete(zipFilePath);
                    end
                    switch e.identifier
                        case 'MATLAB:webservices:OperationTerminatedByUser'
                            error("QLabs:UserCanceledDownload","QLabs installer download cancelled")
                        case 'MATLAB:webservices:UnknownHost'
                            error("QLabs:UnknownHost","Cannot reach %s web server.  Check internet connection.",QLabs.DownloadHost)
                        otherwise
                            rethrow(e);
                    end
                end

                % Handle HTTP responses
                if httpResponse.StatusCode ~= matlab.net.http.StatusCode.OK
                    error("QLabs:DownloadUnsuccessful","HTTP code %.0f (%s) when downloading ZIP file.",double(httpResponse.StatusCode),httpResponse.StatusCode)
                end
                if ~QLabs.isZipPresent()
                    error("QLabs:CannotFindZipFile","Cannot find Zip file after successful download.")
                end
            end

            % Unzip the downloaded file
            if QLabs.isZipPresent() && ~QLabs.isInstallerPresent()
                % If the ZIP is downloaded, but the Install EXE isn't
                % present, then unzip
                zipFilePath = fullfile(QLabs.DownloadDir,QLabs.ZipFileName);
                try
                    files = unzip(zipFilePath,QLabs.DownloadDir);
                catch e
                    switch e.identifier
                        case 'MATLAB:io:archive:unzip:invalidZipFile'
                            if QLabs.isZipPresent()
                                delete(zipFilePath);
                            end
                            error("QLabs:BadDownload","QLabs download unsuccessful.  Please retry.")
                        otherwise
                            rethrow(e)
                    end
                end

                % Make sure that we got the install file we expected.
                if ~iscell(files) || ~numel(files) == 1
                    error("QLabs:UnexpectedPayload","ZIP File Downloaded didn't match expected contents.")
                end
                [~,name,ext] = fileparts(string(files{1}));
                if name + ext ~= QLabs.InstallerFileName
                    error("QLabs:UnexpectedPayload","ZIP File Downloaded didn't match expected contents.")
                end
                if ~QLabs.isInstallerPresent()
                    error("QLabs:CannotFindInstaller","Cannot find installer after successful unzipping.")
                end
            end
        end

        function register()
            % register Open the registration web page for Quanser Interactive Labs in the system browser

            QLabs.errorIfPlatformInvalid;
            portalURI = QLabs.createSecureURI(QLabs.RegistrationHost, QLabs.RegistrationPath);
            stat = web(portalURI,"-browser");
            if stat ~= 0
                error("QLabs:CouldNotLaunchBrowser",'Could not launch system browser. Please visit the QLabs registration page for MathWorks Academic Site License users at <a href="%s">QLabs Registration</a> in your web browser.',portalURI.EncodedURI);
            end
        end

        function install()
            % install Install Quanser Interactive Labs.  Will download if needed.

            QLabs.errorIfPlatformInvalid;
            if QLabs.isInstalled()
                % It's already installed,  don't install again.
                return
            end
            if ~QLabs.isInstallerPresent()
                % If the installer isn't present, download and install
                QLabs.download();
            end

            installerPath = fullfile(QLabs.DownloadDir,QLabs.InstallerFileName);
            exitCode = system("""" + installerPath + """ /install");
            switch exitCode
                case 0
                    %success
                case 1602
                    error("QLabs:UserCanceledInstall","QLabs install cancelled")
                otherwise
                    error("QLabs:UserInstallFailed","QLabs install failed with a %d exit code",exitCode)
            end
        end

        function launch()
            % launch Launch Quanser Interactive Labs.  Will install if needed.

            QLabs.errorIfPlatformInvalid;
            if ~QLabs.isInstalled()
                % It's not installed, download and install
                QLabs.install();
            end

            qlabPath = fullfile(QLabs.getQLabsDirectory(),QLabs.QLabFileName);
            try
                % Launch using .NET interface to avoid ugly command window
                System.Diagnostics.Process.Start(qlabPath);
            catch
                
                try
                    % Alternative: Launch using system with trailing
                    % ampersand to return immediately.
                    system(qlabPath + " &");
                catch
                    error("QLabs:CouldNotLaunch","Could not launch QLabs")
                end
            end
        end

        function uninstall()
            % uninstall Uninstall Quanser Interactive Labs.

            QLabs.errorIfPlatformInvalid;
            if ~QLabs.isInstalled()
                % It's not installed,  don't try to uninstall.
                return
            end
            installerPath = fullfile(QLabs.DownloadDir,QLabs.InstallerFileName);
            exitCode = system("""" + installerPath + """ /uninstall");
            switch exitCode
                case 0
                case 1602
                    error("QLabs:UserCanceledInstall","QLabs uninstall cancelled")
                otherwise
                    error("QLabs:UserInstallFailed","QLabs uninstall failed with a %d exit code",exitCode)
            end

            % Remove the temporary files
            QLabs.deleteZipAndInstaller();
        end        
    end

    methods(Static, Hidden, Access = public)
        % These utility functions are accessible, but undocumented.

        function result = isZipPresent()
            % isZipPresent Returns true if the ZIP file is present in the temporary directory.

            QLabs.errorIfPlatformInvalid;
            zipFilePath = fullfile(QLabs.DownloadDir,QLabs.ZipFileName);
            result = logical(exist(zipFilePath,"file"));
        end
        
        function result = isInstallerPresent()
            % isInstallerPresent Returns true if the installer is present in the temporary directory.

            QLabs.errorIfPlatformInvalid;
            installerFilePath = fullfile(QLabs.DownloadDir,QLabs.InstallerFileName);
            result = logical(exist(installerFilePath,"file"));
        end
        
        function deleteZipAndInstaller()
            % deleteZipAndInstaller Removes the ZIP file and installer from the temporary directory.

            QLabs.errorIfPlatformInvalid;
            if QLabs.isZipPresent()
                zipFilePath = fullfile(QLabs.DownloadDir,QLabs.ZipFileName);
                delete(zipFilePath);            
            end
            if QLabs.isInstallerPresent()
                installerFilePath = fullfile(QLabs.DownloadDir,QLabs.InstallerFileName);
                delete(installerFilePath);
            end
        end
        
        function result = isInstalled()
            % isInstalled Returns true if QLabs is installed.
            QLabs.errorIfPlatformInvalid;

            % Check the registry
            try
                winqueryreg("name","HKEY_LOCAL_MACHINE",QLabs.QLabInstalledRegistrationSubKey);
            catch
                result = false;
                return
            end
            
            % Look for the .EXE
            qlabPath = fullfile(QLabs.getQLabsDirectory(),QLabs.QLabFileName);
            result = logical(exist(qlabPath,"file"));
        end
    end

    methods(Static, Access = private)
        function result = createSecureURI(host, path, filename)
            % createSecureURI Utility function to construct a secure URI.
            
            arguments
                host (1,1) string;
                path (1,1) string;
                filename (1,1) string = "";
            end
            URI = matlab.net.URI;
            URI.Scheme = "https";
            URI.Host = host;
            URI.Path = path;
            if filename ~= ""
                URI.Path(end+1) = filename;
            end
            result = URI.EncodedURI;
        end

        function errorIfPlatformInvalid
            % errorIfPlatformInvalid Throws an error on any platform other than win64

            archstr = string(computer("arch"));
            if archstr ~= "win64"
                throwAsCaller(MException("QLabs:Unsupported Platform","QLabs requires 64-bit Windows platform."))
            end
        end

        function path = getQLabsDirectory()
            % getQLabsDirectory Gets the QLab directory in program files

            path = fullfile(QLabs.getProgramFilesDirectory(),join(QLabs.QLabFilePathInProgramFiles,filesep));
            if ~logical(exist(path,"dir"))
                error("QLabs:CouldNotFindQLabsEXE","Cannot locate QLabs directory")
            end
        end

        function path = getProgramFilesDirectory()
            %getProgramFilesDirectory Gets the location of the Windows Program Files directory from the registry
            try
                path = strtrim(string(winqueryreg("HKEY_LOCAL_MACHINE","SOFTWARE\Microsoft\Windows\CurrentVersion","ProgramFilesPath")));
            catch e
                error("QLabs:CouldNotFindQLabsEXE","Cannot locate Program Files directory")
            end
            if ~logical(exist(path,"dir"))
                error("QLabs:CouldNotFindQLabsEXE","Cannot locate Program Files directory")
            end
        end
    end

    methods(Access = private)
        function obj = QLabs()
            % We don't actually allow instantiation of the class.
        end
    end    
end

