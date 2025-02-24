#!/usr/bin/env python
"""
impress's sandbox management script.
"""

import os
import sys
from pathlib import Path

if __name__ == "__main__":
    # Load environment variables before Django starts
    env_path = Path(__file__).resolve().parent / '.env'
    if env_path.exists():
        with open(env_path) as f:
            for line in f:
                if line.strip() and not line.startswith('#'):
                    key, value = line.strip().split('=', 1)
                    os.environ[key] = value

    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "impress.settings")
    os.environ.setdefault("DJANGO_CONFIGURATION", "Development")

    from configurations.management import execute_from_command_line

    execute_from_command_line(sys.argv)
