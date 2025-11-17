import SwiftUI

struct RightPanelPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Right Panel")
                .font(.largeTitle.bold())
            Text("Placeholder content for the rightmost page.")
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct RightPanelPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        RightPanelPlaceholderView()
    }
}
