import SwiftUI

struct SearchBarWithLimits: View {
    @StateObject private var usageService = UsageService.shared
    @State private var searchText = ""
    @State private var showUpgradePrompt = false
    @State private var isSearching = false
    var showBanner: Bool
    
    // Callback for when search is performed
    var onSearch: (String) async -> Void
    
    // Initializers for different use cases
    init(showBanner: Bool = true, onSearch: @escaping (String) async -> Void) {
        self.showBanner = showBanner
        self.onSearch = onSearch
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Usage indicator - only show if showBanner is true AND limits are low
            if showBanner && usageService.shouldShowLimitWarning(for: UserAction.search) {  // Fix 2: Explicit type
                limitWarningView
            }
            
            // Main search bar
            searchBarView
        }
        .sheet(isPresented: $showUpgradePrompt) {
            PaywallView()
        }
        .task {
            await usageService.refreshUsageStats()
        }
    }
    
    // MARK: - Subviews
    
    private var limitWarningView: some View {
        HStack {
            Image(systemName: "exclamationmark.circle")
                .foregroundColor(usageService.getLimitColor(for: UserAction.search))  // Fix: Explicit type
            
            Text(usageService.formattedLimitMessage(for: UserAction.search))  // Fix: Explicit type
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
            
            if !usageService.isPremium {
                Button("Upgrade") {
                    showUpgradePrompt = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .background(usageService.getLimitColor(for: UserAction.search).opacity(0.1))  // Fix: Explicit type
        .cornerRadius(8)
        .padding(.horizontal)
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search recipes...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .disabled(usageService.hasReachedSearchLimit || isSearching)
                .onSubmit {
                    performSearch()
                }
            
            // Clear button
            if !searchText.isEmpty && !isSearching {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            // Search button or loading indicator
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button("Search") {
                    performSearch()
                }
                .disabled(searchText.isEmpty || usageService.hasReachedSearchLimit)
                .font(.callout)
                .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
    
    // MARK: - Actions
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        Task {
            isSearching = true
            defer { isSearching = false }
            
            let allowed = await usageService.checkAndPerformAction(UserAction.search)  // Fix: Explicit type
            
            if allowed {
                await onSearch(searchText)
                await usageService.refreshUsageStats()
            } else {
                showUpgradePrompt = true
            }
        }
    }
}
