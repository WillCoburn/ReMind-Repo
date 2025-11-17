import SwiftUI

struct CommunityView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Community")
                .font(.largeTitle.bold())
            Text("Placeholder content for the leftmost page.")
                .font(.callout)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct CommunityView_Previews: PreviewProvider {
    static var previews: some View {
        CommunityView()
    }
}
