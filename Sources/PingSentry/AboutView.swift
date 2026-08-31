import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 44))
                .foregroundStyle(.tint)

            Text("PingSentry")
                .font(.title2)
                .bold()

            Text("Versione \(AppVersion.current)")
                .foregroundStyle(.secondary)

            Text("Monitor di rete da barra menu: ping periodico su un host a scelta, con indicatore di qualità e percentuale di pacchetti persi.")
                .multilineTextAlignment(.center)
                .font(.callout)
                .frame(maxWidth: 280)

            Link("Repository su GitLab", destination: URL(string: "http://gitlab.gaskb.net/root/pingsentry")!)
                .font(.callout)

            Text("Sviluppato da Gas")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 320, height: 320)
    }
}
