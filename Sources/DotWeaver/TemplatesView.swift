import SwiftUI
import DotWeaverKit

struct DotTemplate: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let defaultPath: String
    let content: String
    let icon: String
    let color: Color
}

struct TemplatesView: View {
    @EnvironmentObject private var viewModel: DotfilesViewModel
    
    let templates = [
        DotTemplate(
            name: "Oh My Zsh",
            description: "A delightful, open source, community-driven framework for managing your Zsh configuration.",
            defaultPath: "~/.zshrc",
            content: "# Oh My Zsh configuration\nexport ZSH=\"$HOME/.oh-my-zsh\"\nZSH_THEME=\"robbyrussell\"\nplugins=(git)\nsource $ZSH/oh-my-zsh.sh\n",
            icon: "terminal.fill",
            color: .green
        ),
        DotTemplate(
            name: "Starship",
            description: "The minimal, blazing-fast, and infinitely customizable prompt for any shell!",
            defaultPath: "~/.config/starship.toml",
            content: "[character]\nsuccess_symbol = \"[➜](bold green)\"\nerror_symbol = \"[➜](bold red)\"\n",
            icon: "star.fill",
            color: .orange
        ),
        DotTemplate(
            name: "Basic Vimrc",
            description: "A simple and sane .vimrc for general purpose editing.",
            defaultPath: "~/.vimrc",
            content: "set number\nset relativenumber\nset expandtab\nset tabstop=4\nset shiftwidth=4\nsyntax on\n",
            icon: "leaf.fill",
            color: .green
        )
    ]
    
    let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 24)
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Template Gallery")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Kickstart your environment with these curated dotfile templates.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(templates) { template in
                        TemplateCard(template: template) {
                            applyTemplate(template)
                        }
                    }
                }
            }
            .padding(40)
        }
    }
    
    private func applyTemplate(_ template: DotTemplate) {
        let url = URL(fileURLWithPath: (template.defaultPath as NSString).expandingTildeInPath)
        
        do {
            guard let data = template.content.data(using: .utf8) else {
                throw NSError(domain: "DotWeaver.Templates", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode template content"])
            }
            try SyncPathSecurity.writeFileAtomically(data, to: url)
            
            // Add to viewModel if not already there
            if !viewModel.dotfiles.contains(where: { $0.path == template.defaultPath }) {
                let newFile = Dotfile(path: template.defaultPath, status: .synced, isMonitored: true)
                viewModel.dotfiles.append(newFile)
            }
            
            viewModel.addActivityLog(message: "Applied template: \(template.name)", type: .add)
            viewModel.statusMessage = "Applied \(template.name) to \(template.defaultPath)"
            viewModel.startWatchingDotfiles()
            
        } catch {
            viewModel.statusMessage = "Error applying template: \(error.localizedDescription)"
        }
    }
}

struct TemplateCard: View {
    let template: DotTemplate
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 16) {
                Image(systemName: template.icon)
                    .font(.title)
                    .foregroundStyle(template.color)
                    .frame(width: 50, height: 50)
                    .background(template.color.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                    Text(template.defaultPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Text(template.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .frame(height: 50, alignment: .top)
            
            Button(action: action) {
                Text("Apply Template")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isHovered ? Color.blue.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}
