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

import configparser
import logging
import os
import re
from pathlib import Path


class RedfishClientInjectorPlugin:
    """Plugin to inject RedfishClient DSC includes into platform DSC file."""

    def __init__(self):
        """Initialize the plugin and load configuration."""
        self.config = configparser.ConfigParser()
        self.config_file = Path("RedfishClientInjector.ini")
        self._load_config()

    def _load_config(self):
        """Load configuration from INI file with defaults."""
        # Set default configuration
        self.config.add_section('RedfishClient')
        self.config.set('RedfishClient', 'enabled', 'true')
        self.config.set('RedfishClient', 'defines_include', 'RedfishClientPkg/RedfishClientDefines.dsc.inc')
        self.config.set('RedfishClient', 'components_include', 'RedfishClientPkg/RedfishClient.dsc.inc')
        self.config.set('RedfishClient', 'skip_if_exists', 'true')
        self.config.set('RedfishClient', 'add_components_comment', 'true')
        self.config.set('RedfishClient', 'components_comment', '# RedfishClient components, libraries, and PCDs')
        
        self.config.add_section('Logging')
        self.config.set('Logging', 'level', 'INFO')
        self.config.set('Logging', 'verbose', 'false')
        
        # Load from file if it exists
        if self.config_file.exists():
            try:
                self.config.read(self.config_file)
                logging.info(f"Loaded configuration from {self.config_file}")
            except Exception as e:
                logging.warning(f"Failed to load config file {self.config_file}: {e}")
        else:
            # Create default config file
            self._create_default_config()

    def _create_default_config(self):
        """Create a default configuration file."""
        try:
            with open(self.config_file, 'w') as f:
                f.write("""# RedfishClient Injector Plugin Configuration
# This file controls the behavior of the RedfishClient DSC injection plugin

[RedfishClient]
# Enable/disable the plugin
enabled = true

# DSC include files to inject
defines_include = RedfishClientPkg/RedfishClientDefines.dsc.inc
components_include = RedfishClientPkg/RedfishClient.dsc.inc

# Skip injection if includes already exist
skip_if_exists = true

# Add comment before components include
add_components_comment = true
components_comment = # RedfishClient components, libraries, and PCDs

[Logging]
# Logging level (DEBUG, INFO, WARNING, ERROR)
level = INFO
verbose = false
""")
            logging.info(f"Created default configuration file: {self.config_file}")
        except Exception as e:
            logging.warning(f"Failed to create default config file: {e}")

    def _is_enabled(self) -> bool:
        """Check if the plugin is enabled."""
        return self.config.getboolean('RedfishClient', 'enabled', fallback=True)

    def _get_defines_include(self) -> str:
        """Get the defines include file path."""
        return self.config.get('RedfishClient', 'defines_include', 
                              fallback='RedfishClientPkg/RedfishClientDefines.dsc.inc')

    def _get_components_include(self) -> str:
        """Get the components include file path."""
        return self.config.get('RedfishClient', 'components_include', 
                              fallback='RedfishClientPkg/RedfishClient.dsc.inc')

    def _should_skip_if_exists(self) -> bool:
        """Check if we should skip injection if includes already exist."""
        return self.config.getboolean('RedfishClient', 'skip_if_exists', fallback=True)

    def _should_add_comment(self) -> bool:
        """Check if we should add a comment before components include."""
        return self.config.getboolean('RedfishClient', 'add_components_comment', fallback=True)

    def _get_components_comment(self) -> str:
        """Get the comment to add before components include."""
        return self.config.get('RedfishClient', 'components_comment', 
                              fallback='# RedfishClient components, libraries, and PCDs')

    def _is_verbose(self) -> bool:
        """Check if verbose logging is enabled."""
        return self.config.getboolean('Logging', 'verbose', fallback=False)

    def do_pre_build(self, builder) -> int:
        """Inject RedfishClient includes into the platform DSC file.
        
        Args:
            builder: UefiBuild object for env information
            
        Returns:
            int: 0 for success, non-zero for failure
        """
        try:
            # Check if plugin is enabled
            if not self._is_enabled():
                if self._is_verbose():
                    logging.info("RedfishClient injector plugin is disabled")
                return 0

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
                
            if self._is_verbose():
                logging.info(f"Processing DSC file: {dsc_file_path}")
            
            # Read the DSC file
            with open(dsc_file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                
            # Get include file paths from configuration
            defines_include = self._get_defines_include()
            components_include = self._get_components_include()
            
            # Check if RedfishClient is already included
            if self._should_skip_if_exists():
                if defines_include in content:
                    if self._is_verbose():
                        logging.info("RedfishClient defines already included in DSC file")
                    return 0
                if components_include in content:
                    if self._is_verbose():
                        logging.info("RedfishClient components already included in DSC file")
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
                    
            # Insert the RedfishClient defines include
            if defines_include not in content:
                lines.insert(insert_index, f"  !include {defines_include}")
                if self._is_verbose():
                    logging.info(f"Added defines include: {defines_include}")
            
            # Reconstruct the defines section
            new_defines_section = '\n'.join(lines)
            
            # Replace the defines section in the content
            new_content = content.replace(defines_section, new_defines_section)
            
            # Add the main RedfishClient.dsc.inc at the end of the file
            if components_include not in new_content:
                # Add include at the end of file
                new_content += "\n\n"
                if self._should_add_comment():
                    new_content += self._get_components_comment() + "\n"
                new_content += f"!include {components_include}\n"
                if self._is_verbose():
                    logging.info(f"Added components include: {components_include}")
            
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
