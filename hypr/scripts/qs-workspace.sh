#!/bin/bash
ACTIVE=$(cat /tmp/qs_active_widget 2>/dev/null || echo "hidden")
if [ "$ACTIVE" = "workspaces" ]; then
    echo "close" > /tmp/qs_widget_state
else
    echo "workspaces" > /tmp/qs_widget_state
fi
