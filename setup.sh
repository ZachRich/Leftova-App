#!/bin/bash

# Setup script for Leftova development environment

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🚀 Setting up Leftova development environment..."
echo ""

# Check if Config.swift exists
if [ ! -f "Leftova/Config/Config.swift" ]; then
    echo -e "${YELLOW}⚠️  Config.swift not found. Creating from template...${NC}"
    cp Leftova/Config/Config.template.swift Leftova/Config/Config.swift
    echo -e "${RED}❗ IMPORTANT: Edit Leftova/Config/Config.swift with your Supabase credentials${NC}"
    echo ""
else
    echo -e "${GREEN}✅ Config.swift already exists${NC}"
fi

# Install git hooks
echo "Installing git hooks..."
if [ -f ".githooks/pre-commit" ]; then
    cp .githooks/pre-commit .git/hooks/pre-commit
    chmod +x .git/hooks/pre-commit
    echo -e "${GREEN}✅ Pre-commit hook installed${NC}"
else
    echo -e "${YELLOW}⚠️  Pre-commit hook not found${NC}"
fi

# Check if .gitignore exists
if [ -f ".gitignore" ]; then
    echo -e "${GREEN}✅ .gitignore exists${NC}"
else
    echo -e "${RED}❌ .gitignore not found! Your secrets may be exposed!${NC}"
fi

# Check if Config.swift is gitignored
if git check-ignore "Leftova/Config/Config.swift" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Config.swift is properly gitignored${NC}"
else
    echo -e "${RED}❌ WARNING: Config.swift is NOT gitignored! Your API keys will be exposed!${NC}"
    echo -e "${YELLOW}   Add 'Config.swift' to your .gitignore immediately${NC}"
fi

echo ""
echo "📋 Setup Checklist:"
echo "  1. Edit Leftova/Config/Config.swift with your Supabase credentials"
echo "  2. Never commit Config.swift to git"
echo "  3. Rotate your keys if they've been exposed"
echo "  4. Read SECURITY_SETUP.md for detailed security guidelines"
echo ""
echo -e "${GREEN}✨ Setup complete!${NC}"