import SwiftUI
import Lottie

struct LottieAnimationPlayer: UIViewRepresentable {
    let name: String
    var loopMode: LottieLoopMode = .loop
    var playTrigger: Int = 0
    var animationSpeed: CGFloat = 1

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> LottieAnimationView {
        let view = LottieAnimationView(name: name)
        view.contentMode = .scaleAspectFit
        view.backgroundBehavior = .pauseAndRestore
        view.loopMode = loopMode
        view.animationSpeed = animationSpeed
        context.coordinator.animationName = name
        context.coordinator.playTrigger = playTrigger
        view.play()
        return view
    }

    func updateUIView(_ view: LottieAnimationView, context: Context) {
        view.contentMode = .scaleAspectFit
        view.backgroundBehavior = .pauseAndRestore
        view.loopMode = loopMode
        view.animationSpeed = animationSpeed

        if context.coordinator.animationName != name {
            context.coordinator.animationName = name
            view.stop()
            view.animation = LottieAnimation.named(name)
            view.currentProgress = 0
            view.play()
        } else if context.coordinator.playTrigger != playTrigger {
            context.coordinator.playTrigger = playTrigger
            view.currentProgress = 0
            view.play()
        } else if loopMode == .loop && !view.isAnimationPlaying {
            view.play()
        }
    }

    final class Coordinator {
        var animationName: String?
        var playTrigger = -1
    }
}
