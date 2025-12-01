#!/usr/bin/env python3
"""
Example hook script for Claude Code plugins.

This script receives tool input via stdin and can:
- Return JSON to modify behavior
- Exit 0 to approve (with optional JSON response)
- Exit 2 to block the operation

Environment variables available:
- CLAUDE_PROJECT_DIR: Project root directory
- CLAUDE_PLUGIN_ROOT: Plugin root directory (in plugins)
"""

import json
import sys
import os


def main():
    # Read input from stdin
    input_data = sys.stdin.read()

    try:
        tool_input = json.loads(input_data)
    except json.JSONDecodeError:
        tool_input = {"raw": input_data}

    # Access environment variables
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", "")
    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT", "")

    # Example: Check for potentially dangerous operations
    # Uncomment and customize as needed:
    #
    # if "rm -rf" in str(tool_input):
    #     response = {
    #         "decision": "block",
    #         "reason": "Blocking potentially dangerous rm -rf command"
    #     }
    #     print(json.dumps(response))
    #     sys.exit(2)

    # Default: approve with optional system message
    response = {
        "decision": "approve",
        # Uncomment to show a warning message:
        # "systemMessage": "Reminder: Check your code for security issues"
    }

    print(json.dumps(response))
    sys.exit(0)


if __name__ == "__main__":
    main()
