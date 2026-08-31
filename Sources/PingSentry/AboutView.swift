import SwiftUI

struct AboutView: View {
    @AppStorage(Localization.appLanguageDefaultsKey) private var appLanguage: String = AppLanguage.system.rawValue

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("PingSentry")
                .font(.title2)
                .bold()

            Text(L("about.version_format", AppVersion.current))
                .foregroundStyle(.secondary)

            Text(L("about.description"))
                .multilineTextAlignment(.center)
                .font(.callout)
                .frame(maxWidth: 280)

            Link(L("about.repository"), destination: URL(string: "http://gitlab.gaskb.net/root/pingsentry")!)
                .font(.callout)

            Text(L("about.developer"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 320, height: 320)
    }
}
