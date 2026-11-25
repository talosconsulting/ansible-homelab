#!/usr/bin/env bash
set -euo pipefail

ssh zeus "rclone copyto /mnt/raid/Documents/ onedrive:/books/"
