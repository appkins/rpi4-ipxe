#!/usr/bin/env bash

.venv/bin/stuart_setup -c RpiPlatformBuild.py
.venv/bin/stuart_update -c RpiPlatformBuild.py
.venv/bin/stuart_build -c RpiPlatformBuild.py