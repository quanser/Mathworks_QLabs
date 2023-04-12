classdef QLabs
    %QLabs setup, and launch Quanser Interactive Labs
    %   A set of functions to make it easy to setup and use Quanser Interactive Labs.
    %
    %   * Type QLabs.setup to setup Quanser Interactive Labs after installing the add-on (only need to run it once).
    %   * Type QLabs.register to go to the Quanser registration page. You need a QLabs account to use Quanser Interactive Labs.
    %   * Type QLabs.launch to launch the Quanser Interactive Labs.
    %   * Type QLabs.remove to remove Quanser Interactive Labs. Need to run this before uninstalling the add-on.
    
    properties(Hidden, Constant)
        Arch = string(computer("arch"));

        % Registration portal information
        RegistrationHost = "www.quanser.com";
        RegistrationPath = "mathworks-qlabs-trial";

        %Installed Application info
        QLabInstalledRegistrationSubKey = "SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UpgradeCodes\8846B7B58AF54674387D6C27459B5088";
        QLabFilePathInProgramFiles = ["Quanser","Quanser Interactive Labs"];        
    end
    
    methods(Static, Access = public)
        function register()
            % register Open the registration web page for Quanser Interactive Labs in the system browser

            QLabs.errorIfPlatformInvalid;
            portalURI = QLabs.createSecureURI(QLabs.RegistrationHost, QLabs.RegistrationPath);
            stat = web(portalURI,"-browser");
            if stat ~= 0
                error("QLabs:CouldNotLaunchBrowser",'We could not launch your default browser. Please visit the Quanser Interactive Labs registration page for MathWorks Academic Site License users to register at <a href="%s">QLabs Registration</a>.',portalURI.EncodedURI);
            end
        end

        function setup()
            % Setup Quanser Interactive Labs.
            QLabs.errorIfPlatformInvalid;
            if QLabs.isInstalled()
                % It's already installed,  don't install again.
                return
            end
            if ~QLabs.isInstallerPresent()
                % If the installer isn't present, something is wrong with
                % the add-on installation. Prompt user to reinstall the
                % add-on.
                error("QLabs:UserInstallFailed","The Quanser Interactive Labs installer is missing. Please ensure that you have installed the Quanser Interactive Labs for MATLAB add-on.")
            end

            installerPath = fullfile(QLabs.getDownloadDir,QLabs.getInstallerFileNames());
            current_dir = cd;
            if QLabs.Arch == "maci64"
                num_installer = numel(installerPath);
                useful_prompt_shown = false;
                for i = 1 : num_installer
                    [installer_dir, ~, ~] = fileparts(installerPath{i});
                    
                    % Run the QSI installers.
                    cd(installer_dir)
                    if ~useful_prompt_shown
                        disp('Thank you for your interest in Quanser Interactive Labs (QLabs).');
                        disp('This process will install the QLabs application and supporting software for MATLAB Simulink.');
                        disp('The setup process will take some time, but please do not interrupt the installation process.');
                        disp('Please enter your system password when prompted so that the installer can configure our real-time support software.');
                        useful_prompt_shown = true;
                    end
                    [exitCode, result] = system('sudo ./setup -q', '-echo');
                    switch exitCode
                        case 0
                            %success
                            if i == num_installer
                                disp([int2str(i),' / ',int2str(num_installer),' Complete.']);
                            else
                                disp([int2str(i),' / ',int2str(num_installer),' Complete...']);
                            end
                        otherwise
                            error("QLabs:UserInstallFailed","Install failed with a %d exit code and result %s. Please contact Quanser support for assistance.",exitCode,result)
                    end
                end
                disp('Success. Continuing with the installation...');
            else
                disp('Thank you for your interest in Quanser Interactive Labs (QLabs).');
                disp('This process will install the QLabs application and supporting software for MATLAB Simulink.');
                disp('The setup process will take some time, but please do not interrupt the installation process.');
                disp('Please follow the Quanser Interactive Labs Setup dialog when prompted so that the installer can configure our real-time support software.');
                exitCode = system("""" + installerPath + """ /install");
                switch exitCode
                    case 0
                        %success
                        disp('Success. Continuing with the installation...');
                    case 1602
                        error("QLabs:UserCanceledInstall","Quanser Interactive Labs installation cancelled")
                    otherwise
                        error("QLabs:UserInstallFailed","Quanser Interactive Labs installation failed with a %d exit code. Please contact Quanser support for assistance.",exitCode)
                end
            end

            % Set up QUARC in MATLAB so that the user doesn't need to
            % restart MATLAB before being able to use QUARC's blocks.
            cd(fullfile(QLabs.getQUARCDirectory,"quarc"))
            quarc_setup;
            cd(current_dir);

            uiwait(helpdlg('If your institution has a MATLAB site license, do not forget to register for your free Quanser Interactive Labs account using the MATLAB command ''QLabs.register'' before launching the application. ', 'QLabs Reminder'))
            disp('Setup Complete!')
        end

        function launch()
            % launch Launch Quanser Interactive Labs.  Will install if needed.

            QLabs.errorIfPlatformInvalid;
            if ~QLabs.isInstalled()
                % It's not installed, install it.
                QLabs.setup();
            end

            if QLabs.Arch == "maci64"
                try
                    system('open -a QLabs');
                catch
                    error("QLabs:CouldNotLaunch","Could not launch Quanser Interactive Labs. Please contact Quanser support for assistance.")
                end
            else
                qlabPath = fullfile(QLabs.getQLabsDirectory(),QLabs.getQLabsFileName());
                try
                    % Launch using .NET interface to avoid ugly command window
                    System.Diagnostics.Process.Start(qlabPath);
                catch
                    
                    try
                        % Alternative: Launch using system with trailing
                        % ampersand to return immediately.
                        system(qlabPath + " &");
                    catch
                        error("QLabs:CouldNotLaunch","Could not launch Quanser Interactive Labs. Please contact Quanser support for assistance.")
                    end
                end
            end
        end

        function remove()
            % Unsetup Quanser Interactive Labs.
            QLabs.errorIfPlatformInvalid;
            if ~QLabs.isInstalled()
                % It's not installed,  don't try to uninstall.
                return
            end

            % Remove QUARC directories from MATLAB, so that users do not
            % have to restart MATLAB to have the QUARC path removed.
            if logical(exist('quarc_setup', "file"))
                quarc_setup(0);
            end
            
            if QLabs.Arch == "maci64"
                % Run the QSI uninstaller
                uninstallerPath = QLabs.getUninstallerFileNames();
                num_uninstaller = numel(uninstallerPath);
                useful_prompt_shown = false;
                for i = 1 : num_uninstaller
                    if ~useful_prompt_shown
                        disp('Removing Quanser Interactive Labs including files from system folders.');
                        disp('Please enter your system password when prompted.');
                        useful_prompt_shown = true;
                    end
                    % Run the QSI uninstallers.
                    uninstaller_command = "sudo " + uninstallerPath{i} + " -q";
                    %disp(['Uninstalling ' uninstallerPath{i}])
                    [exitCode, result] = system(uninstaller_command, '-echo');
                    switch exitCode
                        case 0
                            %success
                            if i < num_uninstaller
                                disp(['Removed ',int2str(i), ' / ',int2str(num_uninstaller),'. Continuing to remove Quanser Interactive Labs...']);
                            else
                                disp(['Removed ',int2str(i), ' / ',int2str(num_uninstaller),'.']);
                                disp('Quanser Interactive Labs has been successfully removed from your system.');
                                disp('Do not forget to uninstall the add-on package from the MATLAB Add-on manager.');
                            end
                        otherwise
                            error("QLabs:UserUnInstallFailed","Quanser Interactive Labs uninstall failed with a %d exit code and result %s. Please contact Quanser support for assistance.",exitCode,result)
                    end
                    
                end
            else
                installerPath = fullfile(QLabs.getDownloadDir,QLabs.getInstallerFileNames());
                exitCode = system("""" + installerPath + """ /uninstall");
                switch exitCode
                    case 0
                        disp('Quanser Interactive Labs has been successfully removed from your system.');
                        disp('Do not forget to uninstall the add-on package from the MATLAB Add-on manager.');
                    case 1602
                        error("QLabs:UserCanceledInstall","Quanser Interactive Labs uninstall cancelled")
                    otherwise
                        error("QLabs:UserUnInstallFailed","Quanser Interactive Labs uninstall failed with a %d exit code. Please contact Quanser support for assistance.",exitCode)
                end
            end
        end
    end

    methods(Static, Hidden, Access = public)
        % These utility functions are accessible, but undocumented.        
        function result = isInstallerPresent()
            % isInstallerPresent Returns true if the installer is present.
            QLabs.errorIfPlatformInvalid;
            result = true;
            installerFilePath = fullfile(QLabs.getDownloadDir,QLabs.getInstallerFileNames());
            num_installer_files = length(installerFilePath);
            if num_installer_files > 1
                for i = 1:num_installer_files
                    result = result && logical(exist(installerFilePath(i),"file"));
                end
            else
                result = logical(exist(installerFilePath,"file"));
            end
        end
                
        function result = isInstalled()
            % isInstalled Returns true if QLabs is installed.
            QLabs.errorIfPlatformInvalid;

            if QLabs.Arch == "win64"
                % Check the registry
                try
                    winqueryreg("name","HKEY_LOCAL_MACHINE",QLabs.QLabInstalledRegistrationSubKey);
                catch
                    result = false;
                    return
                end
            end

            % Look for the executable
            qlabPath = fullfile(QLabs.getQLabsDirectory(),QLabs.getQLabsFileName());
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
            % errorIfPlatformInvalid Throws an error on any platform that
            % we do not support
            if QLabs.Arch ~= "win64" && QLabs.Arch ~= "maci64"
                throwAsCaller(MException("QLabs:Unsupported Platform","Quanser Interactive Labs requires a 64-bit Windows platform."))
            end
        end

        function path = getQuanserDirectory()
            % getQuanserDirectory returns the directory where Quanser software
            % is installed

            if QLabs.Arch == "maci64"
                path = fullfile(filesep,"opt","quanser");
            else
                % For QLab's installed QUARC, we don't allow user to change
                % the locaiton of where QUARC is installed, so it'll always
                % be the proper Program Files\Quanser
                path = fullfile(QLabs.getProgramFilesDirectory(),"Quanser");
            end

            if ~logical(exist(path,"dir"))
                error("QLabs:CouldNotFindQuanserPath","Cannot locate the Quanser directory")
            end
        end

        function path = getQLabsDirectory()
            % getQLabsDirectory returns the directory where QLab is
            % installed

            if QLabs.Arch == "maci64"
                path = fullfile(filesep,"Applications");
            else
                path = fullfile(QLabs.getProgramFilesDirectory(),join(QLabs.QLabFilePathInProgramFiles,filesep));
            end

            if ~logical(exist(path,"dir"))
                error("QLabs:CouldNotFindQLabsPath","Cannot locate the Quanser Interactive Labs directory")
            end
        end

        function path = getQUARCDirectory()
            % getQUARCDirectory returns the directory where QUARC is
            % installed

            if QLabs.Arch == "maci64"
                path = fullfile(QLabs.getQuanserDirectory(),"quarc");
            else
                % For QLab's installed QUARC, we don't allow user to change
                % the locaiton of where QUARC is installed, so it'll always
                % be the proper Program Files\Quanser\QUARC
                path = fullfile(QLabs.getQuanserDirectory(), "QUARC");
            end

            if ~logical(exist(path,"dir"))
                error("QLabs:CouldNotFindQUARCPath","Cannot locate the QUARC Home directory")
            end
        end

        function path = getProgramFilesDirectory()
            %getProgramFilesDirectory Gets the location of the Windows Program Files directory from the registry
            try
                path = strtrim(string(winqueryreg("HKEY_LOCAL_MACHINE","SOFTWARE\Microsoft\Windows\CurrentVersion","ProgramFilesPath")));
            catch e
                error("QLabs:CouldNotFindQLabsEXE","Cannot locate the Program Files directory")
            end
            if ~logical(exist(path,"dir"))
                error("QLabs:CouldNotFindQLabsEXE","Cannot locate the Program Files directory")
            end
        end

        function downloadDir = getDownloadDir()
            % The installer is downloaded by the add-on, and the location
            % is stored in a MATLAB auto-generated function that returns
            % the proper location of the folder on the client's computer.
            downloadDir = Mathworks_QLabs.getInstallationLocation('Quanser Interactive Labs and QUARC Home for MATLAB Simulink');
        end

        function installerNames = getInstallerFileNames()
            if QLabs.Arch == "maci64"
                installerNames = [...
                                string(fullfile('quarc_mac_installer', 'quarc_host_mac.qsi')), ...
                                string(fullfile('qlabs_mac_installer', 'qlabs_mac.qsi'))...
                                ];
            else
                installerNames = "Install QLabs.exe";
            end
        end

        function unInstallerNames = getUninstallerFileNames()
            if QLabs.Arch == "maci64"
                unInstallerNames = QLabs.getQuanserDirectory() + filesep + ["qlabs/bin/uninstall_qlabs", "quarc/bin/uninstall_quarc_host"];
            else
                unInstallerNames = "Install QLabs.exe";
            end
        end

        function qlabsFileName = getQLabsFileName()
            if QLabs.Arch == "maci64"
                qlabsFileName = "QLabs.app";
            else
                qlabsFileName = "Quanser Interactive Labs.exe";
            end
        end
    end

    methods(Access = private)
        function obj = QLabs()
            % We don't actually allow instantiation of the class.
        end
    end    
end

