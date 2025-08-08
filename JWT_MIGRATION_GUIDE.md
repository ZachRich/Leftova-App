# JWT Signing Keys Migration Guide for Leftova

## What Changed with JWT Migration

When you migrate from API keys to JWT signing in Supabase, the key format and usage changes:

### Before (API Keys):
- **Publishable Key**: `sb_publishable_...` (what you had)
- **Secret Key**: `sb_secret_...`

### After (JWT Signing):
- **Anon Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (JWT format)
- **Service Role Key**: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (JWT format, different payload)
- **JWT Secret**: A secret used to sign/verify JWTs (NEVER use in client apps!)

## Steps to Update Your iOS App

### 1. Get Your New Keys from Supabase Dashboard

1. Go to your Supabase project dashboard
2. Navigate to **Settings → API**
3. You'll see:
   - **Project URL**: Keep this the same
   - **anon public**: This is your new anon key (use this!)
   - **service_role**: DO NOT use this in your iOS app
   - **JWT Secret**: DO NOT use this in your iOS app

### 2. Update Config.swift

```swift
enum Config {
    static let supabaseURL = "https://sfstuksodesluvsimeur.supabase.co"
    
    // Use the "anon public" key from your Supabase dashboard
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNmc3R1a3NvZGVzbHV2c2ltZXVyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzMzNDU2NzgsImV4cCI6MjA0ODkyMTY3OH0.YOUR_ACTUAL_KEY_HERE"
    
    // ... rest of config
}
```

### 3. Key Differences with JWT

#### What the Anon Key Contains:
The JWT anon key is a signed token that contains:
- `role: "anon"` - Identifies this as an anonymous user
- `ref: "your-project-ref"` - Your project reference
- `iat` and `exp` - Issue and expiry timestamps

#### Security Model:
- The anon key is **safe to embed** in your iOS app
- It only allows operations that your Row Level Security (RLS) policies permit
- Without authentication, it has very limited access
- When a user logs in, Supabase exchanges this for an authenticated JWT

### 4. Verify Your RLS Policies

With JWT signing, Row Level Security is even more important:

```sql
-- Example: Users can only see their own saved recipes
CREATE POLICY "Users can view own saved recipes" ON saved_recipes
    FOR SELECT USING (auth.uid() = user_id);

-- Example: Anyone can search recipes (even anonymous users)
CREATE POLICY "Anyone can view recipes" ON recipes
    FOR SELECT USING (true);

-- Example: Only authenticated users can save recipes
CREATE POLICY "Authenticated users can save recipes" ON saved_recipes
    FOR INSERT WITH CHECK (auth.uid() = user_id);
```

### 5. Update Your Supabase Client Initialization

No changes needed! The Supabase Swift client works the same way:

```swift
// In SupabaseService.swift
let client = SupabaseClient(
    supabaseURL: URL(string: Config.supabaseURL)!,
    supabaseKey: Config.supabaseAnonKey
)
```

### 6. Testing the Migration

1. **Test Anonymous Access**:
   - Try searching recipes without logging in
   - Should work if your RLS policies allow it

2. **Test Authentication**:
   - Sign up a new user
   - Sign in with existing user
   - Check that the JWT is properly exchanged

3. **Test Authorized Operations**:
   - Save a recipe (requires auth)
   - View saved recipes (requires auth)
   - Delete saved recipes (requires auth)

### 7. Troubleshooting

#### "Invalid API key" Error:
- Make sure you're using the anon key, not service_role or JWT secret
- Verify the key starts with `eyJ...`
- Check that you copied the complete key

#### "JWT expired" Error:
- The JWT keys don't expire like the old API keys
- This error means a user's auth token expired
- Users need to sign in again

#### RLS Policy Errors:
- Check your policies in Supabase dashboard
- Make sure they're using `auth.uid()` for user identification
- Test policies in the SQL editor

## Security Best Practices

### DO ✅:
- Use the **anon public** key in your iOS app
- Implement proper RLS policies
- Store the key in Config.swift (gitignored)
- Rotate keys if exposed

### DON'T ❌:
- Use the **service_role** key in client apps
- Use the **JWT secret** in client apps
- Disable RLS on tables with sensitive data
- Commit keys to version control

## Quick Checklist

- [ ] Got new anon key from Supabase dashboard
- [ ] Updated Config.swift with new anon key
- [ ] Verified Config.swift is gitignored
- [ ] Tested app with new key
- [ ] Checked RLS policies are working
- [ ] Removed old publishable key
- [ ] Committed changes (without Config.swift)

## Need More Help?

- [Supabase JWT Documentation](https://supabase.com/docs/guides/auth/jwts)
- [Row Level Security Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [Supabase Swift Client](https://github.com/supabase/supabase-swift)