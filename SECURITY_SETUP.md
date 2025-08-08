# Security Setup Guide for Leftova

## ⚠️ IMPORTANT: Your API Keys are Currently Exposed!

Your Supabase keys are currently visible in `Config.swift`. Follow these steps immediately to secure them:

## Immediate Steps to Secure Your Keys

### 1. Remove Keys from Git History (CRITICAL!)

Since your keys are already in your git history, you need to:

1. **Rotate your Supabase keys immediately:**
   - Go to your Supabase dashboard
   - Navigate to Settings → API
   - Generate new anon and service keys
   - Update your local Config.swift with the new keys

2. **Remove the old Config.swift from git history:**
   ```bash
   # Remove Config.swift from tracking
   git rm --cached Leftova/Config/Config.swift
   
   # Commit this change
   git commit -m "Remove Config.swift from tracking"
   ```

3. **Clean git history (if you've already pushed to remote):**
   ```bash
   # This rewrites history - be careful if others are using the repo
   git filter-branch --force --index-filter \
     "git rm --cached --ignore-unmatch Leftova/Config/Config.swift" \
     --prune-empty --tag-name-filter cat -- --all
   
   # Force push to remote (this will rewrite history)
   git push origin --force --all
   ```

   **Alternative: Use BFG Repo-Cleaner (easier)**
   ```bash
   # Install BFG
   brew install bfg
   
   # Clean the file
   bfg --delete-files Config.swift
   
   # Clean up the repo
   git reflog expire --expire=now --all && git gc --prune=now --aggressive
   
   # Force push
   git push --force
   ```

### 2. Set Up Configuration Properly

#### Option A: Using Config.swift (Gitignored) - Recommended for Development

1. Your Config.swift is now gitignored and won't be committed
2. Use Config.template.swift as a reference for other developers:
   ```bash
   cp Leftova/Config/Config.template.swift Leftova/Config/Config.swift
   # Then edit Config.swift with your actual keys
   ```

#### Option B: Using Environment Variables (Better for CI/CD)

1. Create a new ConfigManager.swift:

```swift
// Leftova/Config/ConfigManager.swift
import Foundation

enum ConfigManager {
    static let supabaseURL: String = {
        guard let url = ProcessInfo.processInfo.environment["SUPABASE_URL"] else {
            fatalError("SUPABASE_URL not set in environment variables")
        }
        return url
    }()
    
    static let supabaseAnonKey: String = {
        guard let key = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] else {
            fatalError("SUPABASE_ANON_KEY not set in environment variables")
        }
        return key
    }()
}
```

2. Set environment variables in Xcode:
   - Edit Scheme → Run → Arguments → Environment Variables
   - Add SUPABASE_URL and SUPABASE_ANON_KEY

#### Option C: Using a Plist File (Good for Multiple Environments)

1. Create a Secrets.plist file (already gitignored):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SUPABASE_URL</key>
    <string>your-url-here</string>
    <key>SUPABASE_ANON_KEY</key>
    <string>your-key-here</string>
</dict>
</plist>
```

2. Load from plist:
```swift
// Leftova/Config/ConfigManager.swift
enum ConfigManager {
    private static let secrets: [String: Any] = {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            fatalError("Secrets.plist not found")
        }
        return dict
    }()
    
    static let supabaseURL = secrets["SUPABASE_URL"] as! String
    static let supabaseAnonKey = secrets["SUPABASE_ANON_KEY"] as! String
}
```

### 3. For Production/App Store Release

For production builds, use Xcode's build configurations:

1. Create different build configurations (Debug, Release, Staging)
2. Use preprocessor macros or xcconfig files
3. Consider using a service like:
   - AWS Secrets Manager
   - Azure Key Vault
   - Or environment variables in your CI/CD pipeline

### 4. Additional Security Best Practices

1. **Never commit:**
   - API keys
   - Passwords
   - Private keys
   - Certificates
   - Any sensitive configuration

2. **Always use:**
   - Row Level Security (RLS) in Supabase
   - Proper authentication
   - API rate limiting
   - Request validation

3. **Monitor:**
   - Check git history regularly for exposed secrets
   - Use tools like GitGuardian or TruffleHog
   - Monitor your Supabase usage for anomalies

### 5. Team Development

For team development, create a setup script:

```bash
#!/bin/bash
# setup.sh

echo "Setting up Leftova development environment..."

# Check if Config.swift exists
if [ ! -f "Leftova/Config/Config.swift" ]; then
    echo "Creating Config.swift from template..."
    cp Leftova/Config/Config.template.swift Leftova/Config/Config.swift
    echo "⚠️  Please edit Leftova/Config/Config.swift with your Supabase credentials"
else
    echo "✅ Config.swift already exists"
fi

echo "Setup complete!"
```

## Verification Checklist

- [ ] Rotated Supabase keys in dashboard
- [ ] Updated local Config.swift with new keys
- [ ] Removed Config.swift from git tracking
- [ ] Cleaned git history of old keys
- [ ] Verified .gitignore includes Config.swift
- [ ] Created Config.template.swift for reference
- [ ] Tested app with new keys
- [ ] Documented setup process for team

## Emergency Response

If keys are compromised:
1. Immediately rotate keys in Supabase dashboard
2. Check Supabase logs for unauthorized access
3. Review and revoke any suspicious sessions
4. Update all environments with new keys
5. Notify team members

## Need Help?

- [Supabase Security Best Practices](https://supabase.com/docs/guides/auth/security)
- [Git Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [iOS App Security](https://developer.apple.com/documentation/security)