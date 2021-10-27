function newVersion = releaseQLabs(releaseType)
% Release a new version of the toolbox.  Version is automatically
% incremented.  OPTION can be "major", "minor", or "patch" to update
% version number appropriately.
    arguments
        releaseType (1,1) string = "build"
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
        matlab.addons.toolbox.toolboxVersion(packagingProjectFile,newVersion);    
    end
end 
