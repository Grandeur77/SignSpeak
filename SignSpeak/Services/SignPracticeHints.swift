import Foundation

/// Anatomical tips, goal poses, and common confusion pairings for ASL fingerspelling practice.
public struct SignPracticeHint: Sendable {
    public let letter: String
    public let goalDescription: String
    public let quickCorrection: String
    public let commonMistakes: [String: String]

    public static let library: [String: SignPracticeHint] = [
        "A": SignPracticeHint(
            letter: "A",
            goalDescription: "Fist facing outward with thumb resting upright along the side of the index finger.",
            quickCorrection: "Keep your fingers tightly curled into your palm and keep your thumb straight up along the side, not tucked in.",
            commonMistakes: [
                "S": "Your thumb is wrapped across your fingers instead of resting on the side.",
                "T": "Your thumb is tucked between your index and middle fingers.",
                "E": "Your fingers are curled on top of your thumb."
            ]
        ),
        "B": SignPracticeHint(
            letter: "B",
            goalDescription: "Four fingers held straight up and pressed together, with your thumb folded across the palm.",
            quickCorrection: "Keep your four fingers straight up, pressed tightly together. Fold your thumb flat across your palm.",
            commonMistakes: [
                "D": "Only your index finger is pointing up; extend all four fingers.",
                "4": "Your thumb is not folded across the palm."
            ]
        ),
        "C": SignPracticeHint(
            letter: "C",
            goalDescription: "Curve all fingers and thumb into a smooth 'C' cup shape facing to the side.",
            quickCorrection: "Curve all four fingers and thumb together as if holding a tennis ball or cup.",
            commonMistakes: [
                "O": "Fingertips are touching your thumb; leave an open gap for the 'C' shape."
            ]
        ),
        "D": SignPracticeHint(
            letter: "D",
            goalDescription: "Index finger points straight up; middle, ring, pinky touch the thumb tip in an 'O' loop.",
            quickCorrection: "Point your index finger straight up. Touch your middle finger, ring finger, and pinky to your thumb tip.",
            commonMistakes: [
                "F": "You are touching your index to thumb; extend index and touch middle to thumb instead.",
                "1": "Curl the other three fingers down to touch your thumb."
            ]
        ),
        "E": SignPracticeHint(
            letter: "E",
            goalDescription: "All four fingertips curled down tightly to touch the side/tip of the thumb.",
            quickCorrection: "Curl all four fingers down so your fingernails rest against your thumb. Do not let your thumb stick out.",
            commonMistakes: [
                "A": "Your thumb is on the side; fold thumb under your curled fingertips.",
                "S": "Your thumb is wrapped across your fingers; keep fingernails touching thumb tip."
            ]
        ),
        "F": SignPracticeHint(
            letter: "F",
            goalDescription: "Index finger and thumb form an 'OK' circle while middle, ring, and pinky point straight up.",
            quickCorrection: "Extend your middle, ring, and pinky fingers straight up. Bring your index finger down to touch your thumb tip in an 'OK' shape.",
            commonMistakes: [
                "E": "Your index finger is curled down into the palm instead of forming an 'OK' circle with your thumb.",
                "D": "You have your middle fingers touching thumb; touch only your index finger to your thumb.",
                "B": "Separate your index finger and touch it to your thumb tip."
            ]
        ),
        "G": SignPracticeHint(
            letter: "G",
            goalDescription: "Index finger and thumb pointing horizontally forward, parallel to each other.",
            quickCorrection: "Make a fist, then point index finger and thumb horizontally forward like a pinch.",
            commonMistakes: [
                "H": "Extend only your index finger, not middle finger.",
                "L": "Turn your hand horizontally so fingers point sideways."
            ]
        ),
        "H": SignPracticeHint(
            letter: "H",
            goalDescription: "Index and middle fingers extended together horizontally, thumb tucked underneath.",
            quickCorrection: "Extend both your index and middle fingers together pointing sideways, thumb tucked flat.",
            commonMistakes: [
                "G": "Extend both index and middle fingers, not just index.",
                "U": "Rotate your hand so fingers point sideways, not straight up."
            ]
        ),
        "I": SignPracticeHint(
            letter: "I",
            goalDescription: "Pinky finger points straight up with other three fingers folded down over thumb.",
            quickCorrection: "Make a fist, wrap thumb across your middle fingers, and extend only your pinky finger straight up.",
            commonMistakes: [
                "Y": "Fold your thumb down across your palm; do not extend it outward.",
                "J": "Hold steady without tracing a hook motion."
            ]
        ),
        "K": SignPracticeHint(
            letter: "K",
            goalDescription: "Index finger points straight up, middle finger forward at 45 degrees, thumb resting between them.",
            quickCorrection: "Extend index finger up, middle finger forward, and place your thumb between them on your middle knuckle.",
            commonMistakes: [
                "V": "Place your thumb between index and middle fingers, resting on the middle finger joint.",
                "P": "Point your hand upward, not tilted downward."
            ]
        ),
        "L": SignPracticeHint(
            letter: "L",
            goalDescription: "Index finger points straight up and thumb points 90 degrees outward to make an 'L' shape.",
            quickCorrection: "Extend your index finger straight up and thumb outward at a 90-degree angle. Fold other three fingers down.",
            commonMistakes: [
                "G": "Point your index finger straight up towards the ceiling, not sideways."
            ]
        ),
        "M": SignPracticeHint(
            letter: "M",
            goalDescription: "Thumb tucked under first three fingers (index, middle, ring) with fingertips resting on thumb.",
            quickCorrection: "Tuck your thumb under your index, middle, and ring fingers, with pinky resting on the side.",
            commonMistakes: [
                "N": "Tuck thumb under three fingers, not two.",
                "T": "Tuck thumb under three fingers, not one."
            ]
        ),
        "N": SignPracticeHint(
            letter: "N",
            goalDescription: "Thumb tucked under first two fingers (index, middle) with ring and pinky resting on the side.",
            quickCorrection: "Tuck your thumb under your index and middle fingers only.",
            commonMistakes: [
                "M": "Tuck thumb under only two fingers, not three.",
                "T": "Tuck thumb under two fingers, not one."
            ]
        ),
        "O": SignPracticeHint(
            letter: "O",
            goalDescription: "All fingers and thumb touch tips together to form a complete closed 'O' circle.",
            quickCorrection: "Curve all four fingers down to meet your thumb tip, forming a closed circular opening.",
            commonMistakes: [
                "C": "Bring all fingertips together until they touch your thumb tip.",
                "E": "Keep an open circular space inside your hand."
            ]
        ),
        "P": SignPracticeHint(
            letter: "P",
            goalDescription: "Like a 'K' handshape with wrist tilted forward so index finger points horizontally downward.",
            quickCorrection: "Make a 'K' handshape with thumb between index and middle, then tilt your wrist down.",
            commonMistakes: [
                "K": "Tilt your wrist forward so the fingers point down horizontally."
            ]
        ),
        "Q": SignPracticeHint(
            letter: "Q",
            goalDescription: "Like a 'G' handshape with index finger and thumb pointing downward towards the floor.",
            quickCorrection: "Form a pinch with index and thumb, then point them straight down towards the ground.",
            commonMistakes: [
                "G": "Point your fingers downward towards the floor, not sideways."
            ]
        ),
        "R": SignPracticeHint(
            letter: "R",
            goalDescription: "Cross your middle finger over behind your index finger like 'fingers crossed'.",
            quickCorrection: "Extend index and middle fingers up and cross your middle finger tightly over your index finger.",
            commonMistakes: [
                "U": "Cross your middle finger over your index finger instead of holding them side by side."
            ]
        ),
        "S": SignPracticeHint(
            letter: "S",
            goalDescription: "Fist with thumb wrapped across the front of all four folded fingers.",
            quickCorrection: "Curl all four fingers into a tight fist and wrap your thumb firmly across the front of your fingers.",
            commonMistakes: [
                "A": "Wrap your thumb across the front of your fingers, not resting along the side.",
                "E": "Keep your thumb wrapped over your fingers, not under them."
            ]
        ),
        "T": SignPracticeHint(
            letter: "T",
            goalDescription: "Thumb tucked between index and middle fingers, with index curled over the thumb.",
            quickCorrection: "Make a fist and slide your thumb between your index and middle fingers so the tip peeks through.",
            commonMistakes: [
                "M": "Slide thumb between index and middle only, not three fingers.",
                "N": "Slide thumb under only one finger, not two."
            ]
        ),
        "U": SignPracticeHint(
            letter: "U",
            goalDescription: "Index and middle fingers extended straight up, held pressed together.",
            quickCorrection: "Extend index and middle fingers straight up and press them tightly together.",
            commonMistakes: [
                "V": "Squeeze your index and middle fingers together without a gap.",
                "R": "Do not cross your fingers; keep them parallel."
            ]
        ),
        "V": SignPracticeHint(
            letter: "V",
            goalDescription: "Index and middle fingers extended straight up in an open 'V' peace sign.",
            quickCorrection: "Extend index and middle fingers up and spread them apart in a 'V' shape.",
            commonMistakes: [
                "U": "Spread your index and middle fingers apart into a 'V'.",
                "K": "Tuck your thumb across your folded ring finger rather than resting between fingers."
            ]
        ),
        "W": SignPracticeHint(
            letter: "W",
            goalDescription: "Index, middle, and ring fingers extended up and spread apart in a 'W' shape.",
            quickCorrection: "Extend your index, middle, and ring fingers upward, spreading them apart. Thumb holds pinky down.",
            commonMistakes: [
                "V": "Extend three fingers (index, middle, ring), not just two.",
                "B": "Spread your three fingers apart and fold your pinky down with your thumb."
            ]
        ),
        "X": SignPracticeHint(
            letter: "X",
            goalDescription: "Index finger curled into a hook shape like a pirate's hook, other fingers folded.",
            quickCorrection: "Make a fist and crook your index finger into a hooked arc.",
            commonMistakes: [
                "1": "Bend your index finger at the knuckles into a hook."
            ]
        ),
        "Y": SignPracticeHint(
            letter: "Y",
            goalDescription: "Thumb and pinky extended outward in a 'hang loose' shape, middle three fingers folded down.",
            quickCorrection: "Fold your middle, ring, and index fingers into your palm, extending your thumb and pinky outward.",
            commonMistakes: [
                "I": "Extend your thumb out as well as your pinky."
            ]
        )
    ]

    /// Returns title, specific difference subtitle, and quick correction instructions for a target/detected sign pair.
    public static func feedback(target: String, detected: String?) -> (title: String, subtitle: String, correction: String) {
        guard let hint = library[target] else {
            let det = detected ?? "Unknown"
            return (
                title: "Not quite — looks like \"\(det)\"",
                subtitle: "Adjust your finger positions to match the target sign.",
                correction: "Hold your hand steadily in frame and align with the target pose."
            )
        }

        if let detected, let specificMistake = hint.commonMistakes[detected] {
            return (
                title: "Not quite — looks like \"\(detected)\"",
                subtitle: specificMistake,
                correction: hint.quickCorrection
            )
        } else if let detected, detected != target {
            return (
                title: "Not quite — looks like \"\(detected)\"",
                subtitle: "Your hand shape is closer to \"\(detected)\" than \"\(target)\".",
                correction: hint.quickCorrection
            )
        } else {
            return (
                title: "Practice \"\(target)\"",
                subtitle: hint.goalDescription,
                correction: hint.quickCorrection
            )
        }
    }
}
