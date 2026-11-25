import SwiftUI

struct ContentView: View {
    @State private var counter = Counter()

    var body: some View {
        VStack(spacing: 16) {
            Text("Tabchiz")
                .font(.largeTitle)
            Text("\(counter.count)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .monospacedDigit()
            HStack {
                Button("Reset", action: counter.reset)
                    .buttonStyle(.bordered)
                Button("Increment", action: counter.increment)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
