#!/bin/bash
# Revert previous script's modifications since we'll use a precise node script or python script for sed to avoid breaking
cp /app/sql/full_system_v1_backup.sql /app/sql/full_system_v1.sql
