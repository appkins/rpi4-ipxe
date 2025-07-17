## @file RedfishClientInjectorPlugin.py
#
# A build plugin that injects RedfishClient DSC includes into the Raspberry Pi platform DSC file
# during the pre-build phase to enable Redfish functionality.
#
# This plugin modifies the RPi4.dsc file to include the necessary RedfishClient components
# without requiring manual source file modifications.
#
# Copyright (c) 2025. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause-Patent
##

import logging
import os
import re
from pathlib import Path


class RedfishClientInjectorPlugin:
    """Plugin to inject RedfishClient DSC includes into platform DSC file."""

    def do_pre_build(self, builder) -> int:
        """Inject RedfishClient includes into the platform DSC file.
        
        Args:
            builder: UefiBuild object for env information
            
        Returns:
            int: 0 for success, non-zero for failure
        """
        try:
            # Get the active platform DSC file path
            active_platform = builder.env.GetValue("ACTIVE_PLATFORM")
            if not active_platform:
                logging.warning("No ACTIVE_PLATFORM defined, skipping RedfishClient injection")
                return 0
                
            # Get workspace root and package paths
            workspace_root = Path(builder.ws)
            packages_path = builder.env.GetValue("PACKAGES_PATH", "")
            platform_paths = packages_path.split(os.pathsep) if packages_path else []
            
            # Also add workspace root to search paths
            platform_paths.append(str(workspace_root))
            
            dsc_file_path = None
            for pkg_path in platform_paths:
                if not pkg_path:
                    continue
                potential_path = Path(pkg_path) / active_platform
                if potential_path.exists():
                    dsc_file_path = potential_path
                    break
                    
            if not dsc_file_path:
                logging.error(f"Could not find DSC file: {active_platform}")
                return 1
                
            logging.info(f"Processing DSC file: {dsc_file_path}")
            
            # Read the DSC file
            with open(dsc_file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Check if RedfishClient is already included
            if 'RedfishClientPkg/RedfishClientDefines.dsc.inc' in content:
                logging.info("RedfishClient already included in DSC file")
                return 0
                
            # Find the [Defines] section and inject RedfishClient includes
            defines_pattern = r'(\[Defines\][^\[]*)'
            defines_match = re.search(defines_pattern, content, re.MULTILINE | re.DOTALL)
            
            if not defines_match:
                logging.error("Could not find [Defines] section in DSC file")
                return 1
                
            # Insert the include after the [Defines] section header
            defines_section = defines_match.group(1)
            
            # Find a good insertion point (after existing includes or defines)
            lines = defines_section.split('\n')
            insert_index = 1  # After [Defines] line
            
            # Look for existing includes to insert near them
            for i, line in enumerate(lines):
                if '!include' in line.lower() or 'define ' in line:
                    insert_index = i + 1
                    
            # Insert the RedfishClient include
            lines.insert(insert_index, "  !include RedfishClientPkg/RedfishClientDefines.dsc.inc")
            
            # Reconstruct the defines section
            new_defines_section = '\n'.join(lines)
            
            # Replace the defines section in the content
            new_content = content.replace(defines_section, new_defines_section)
            
            # Also need to add the main RedfishClient.dsc.inc at the end of the file
            if 'RedfishClientPkg/RedfishClient.dsc.inc' not in new_content:
                # Add include at the end of file
                new_content += "\n\n# RedfishClient components, libraries, and PCDs\n"
                new_content += "!include RedfishClientPkg/RedfishClient.dsc.inc\n"
            
            # Write the modified content back
            with open(dsc_file_path, 'w', encoding='utf-8') as f:
                f.write(new_content)
                
            logging.info("Successfully injected RedfishClient includes into DSC file")
            return 0
            
        except Exception as e:
            logging.error(f"Failed to inject RedfishClient includes: {e}")
            return 1
            
    def do_post_build(self, builder) -> int:
        """No post-build operations needed."""
        return 0
