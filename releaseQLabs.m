function newVersion = releaseQLabs(releaseType, matlabReleaseEnd)
% Release a new version of the toolbox.  Version is automatically
% incremented.  OPTION can be "major", "minor", or "patch" to update
% version number appropriately.
    arguments
        releaseType (1,1) string = "build"
        matlabReleaseEnd (1,1) string = ""
    end
    
    packagingProjectFile = fullfile("Quanser Interactive Labs for MATLAB.prj");
    
    newVersion = incrementMLTBXVersion(packagingProjectFile,releaseType);
    
    matlab.addons.toolbox.packageToolbox(packagingProjectFile,'release/Quanser_Interactive_Labs_for_MATLAB')
    
    function newVersion = incrementMLTBXVersion(packagingProjectFile, releaseType)
        oldVersion = string(matlab.addons.toolbox.toolboxVersion(packagingProjectFile));
        pat = digitsPattern;
        versionParts = extract(oldVersion,pat);
        if numel(versionParts) == 1
            versionParts(2) = "0";
        end
        if numel(versionParts) == 2
            versionParts(3) = "0";
        end
        if numel(versionParts) == 3
            versionParts(4) = "0";
        end
        
        switch lower(releaseType)
            case "major"
                versionParts(1) = string(str2double(versionParts(1)) + 1);
                versionParts(2) = "0";
                versionParts(3) = "0";
            case "minor"
                versionParts(2) = string(str2double(versionParts(2)) + 1);
                versionParts(3) = "0";
            case "patch"
                versionParts(3) = string(str2double(versionParts(3)) + 1);
        end
        versionParts(4) = string(str2double(versionParts(4)) + 1);
        newVersion = join(versionParts,".");

        doc = xmlread(packagingProjectFile);

        if (updateMLTBXAdditionalSoftwareSource(doc, newVersion))
            
            if (strlength(matlabReleaseEnd) > 0)
                if ~updateMLTBXMATLABReleaseEnd(doc, matlabReleaseEnd);
                    disp('Cannot update last supported MATLAB release.')
                    ret = false;
                end
            end
            
            % Write to the project file
            raw_xml = xmlwrite(doc);
            start_pos = strfind(raw_xml, '<deployment');
            if isempty(start_pos)
                disp('Cannot export to xml.')
                ret = false;
                return
            end

            prj_content = raw_xml(start_pos:end);
            [fid, message] = fopen(packagingProjectFile, 'wt');
            if fid ~= -1
                fprintf(fid, '%s\n', prj_content);
                fclose(fid);
            else
                error(message);
            end
            
            % Use the MATLAB built-in function to update the version number
            matlab.addons.toolbox.toolboxVersion(packagingProjectFile, newVersion);
        else
            error('Cannot update Additional Software source.');
        end
    end

    function ret = updateMLTBXAdditionalSoftwareSource(doc, version)
        pat = digitsPattern;
        versionParts = extract(version, pat);
        version_path = versionParts(1) + '.' + versionParts(2);

        % Set the Windows zip file
        ret = setDownloadPath(doc, version_path, "win64");
        if ~ret
            return
        end

        % Set the Mac zip file
        ret = setDownloadPath(doc, version_path, "maci64");
        if ~ret
            return
        end
    end

    function ret = setDownloadPath(doc, version_path, target)
        ret = true;
        
        % target can come in as "win64" or "maci64", etc.
        % However the MATLAB project file only use "win" or "mac"
        target_char = char(target);
        target_short = string(target_char(1:3));

        url_tag_name = "param.additional.sw." + target_short + ".url";

        url = doc.getElementsByTagName(url_tag_name);
        if (url.getLength ~= 1)
            disp('Cannot find URL element for target: ' + target);
            ret = false;
            return;
        end

        url_item = url.item(0).getElementsByTagName('item');
        if (url_item.getLength ~= 1)
            disp('Cannot find URL/item element for target: ' + target);
            ret = false;
            return;
        end

        content = "https://download.quanser.com/qlabs/" + version_path + "/QLabs_Installer_" + target + ".zip";
        url_item.item(0).setTextContent(content);
    end

    function ret = updateMLTBXMATLABReleaseEnd(doc, matlab_release)
        ret = true;
        
        tag_name = "param.release.end";

        release_end = doc.getElementsByTagName(tag_name);
        if (release_end.getLength ~= 1)
            disp('Cannot find release_end element.');
            ret = false;
            return;
        end

        release_end.item(0).setTextContent(matlab_release);
    end
end 
