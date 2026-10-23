#!/usr/bin/env python3
"""
Generates the comprehensive seed signs.json dataset for SignSpeak Phase 4 Step 4.1.
Covers:
- 26 Alphabet letters (Lessons 1-5: A-E, F-J, K-O, P-T, U-Z)
- 10 Numbers (1-10)
- ~60 core vocabulary words across 9 prototype categories:
  Greetings, Everyday, Emergency, Family, Feelings, Food & Drink, Courtesy, Healthcare, Workplace.
"""

import json
from pathlib import Path

# Categories
CATEGORIES = [
    {
        "id": "alphabet",
        "name": "Alphabet",
        "iconName": "character.bubble",
        "description": "ASL manual alphabet fingerspelling from A to Z.",
        "order": 1,
        "introVideoName": "cat_alphabet_intro"
    },
    {
        "id": "numbers",
        "name": "Numbers",
        "iconName": "number",
        "description": "Cardinal counting numbers 1 through 10 in American Sign Language.",
        "order": 2,
        "introVideoName": "cat_numbers_intro"
    },
    {
        "id": "greetings",
        "name": "Greetings",
        "iconName": "hand.wave",
        "description": "Essential greetings and introductory conversation starters.",
        "order": 3,
        "introVideoName": "cat_greetings_intro"
    },
    {
        "id": "courtesy",
        "name": "Courtesy",
        "iconName": "heart.text.square",
        "description": "Polite expressions, gratitude, and social courtesy.",
        "order": 4,
        "introVideoName": "cat_courtesy_intro"
    },
    {
        "id": "everyday",
        "name": "Everyday",
        "iconName": "calendar",
        "description": "High-frequency conversational signs for daily life.",
        "order": 5,
        "introVideoName": "cat_everyday_intro"
    },
    {
        "id": "family",
        "name": "Family",
        "iconName": "person.2",
        "description": "Family members and interpersonal relationships.",
        "order": 6,
        "introVideoName": "cat_family_intro"
    },
    {
        "id": "feelings",
        "name": "Feelings",
        "iconName": "face.smiling",
        "description": "Emotions, states of mind, and personal expressions.",
        "order": 7,
        "introVideoName": "cat_feelings_intro"
    },
    {
        "id": "food-drink",
        "name": "Food & Drink",
        "iconName": "cup.and.saucer",
        "description": "Common foods, beverages, meals, and dining expressions.",
        "order": 8,
        "introVideoName": "cat_food_drink_intro"
    },
    {
        "id": "healthcare",
        "name": "Healthcare",
        "iconName": "cross.case",
        "description": "Medical signs, symptoms, pain levels, and doctor appointments.",
        "order": 9,
        "introVideoName": "cat_healthcare_intro"
    },
    {
        "id": "workplace",
        "name": "Workplace",
        "iconName": "briefcase",
        "description": "Office interactions, teamwork, schedules, and workplace communication.",
        "order": 10,
        "introVideoName": "cat_workplace_intro"
    },
    {
        "id": "emergency",
        "name": "Emergency",
        "iconName": "exclamationmark.triangle",
        "description": "Crucial urgent signs for safety, help, and first responders.",
        "order": 11,
        "introVideoName": "cat_emergency_intro"
    }
]

# Alphabet Sign Definitions
ALPHABET_DATA = [
    ("A", "AY", "static", "Fist with thumb resting firmly against the side of the index finger.",
     ["Curl all four fingers tightly into your palm.", "Rest your upright thumb flush against the side of the index finger.", "Face your palm forward towards the conversation partner."],
     "Do not wrap your thumb over your fingers (that makes an S).", "Imagine hitchhiking with a clenched fist."),
    ("B", "BEE", "static", "Open hand with four fingers straight up together and thumb folded across the palm.",
     ["Hold all four fingers upright, straight and touching each other.", "Fold your thumb across your open palm resting gently over the lower joints.", "Keep your wrist steady with palm facing forward."],
     "Allowing gaps between fingers resembles the number 4.", "Think of holding up a flat board (B for Board)."),
    ("C", "SEE", "static", "Curved hand forming the letter C with fingers together and thumb opposed.",
     ["Curve all four fingers together in a smooth arc.", "Oppose your thumb below them to trace a semi-circle.", "Hold at chest height with the opening facing slightly left/center."],
     "Do not close fingers too tightly or flatten the arch.", "Your hand literally outlines the letter C."),
    ("D", "DEE", "static", "Index finger pointing straight up while thumb touches the tips of the other three curled fingers.",
     ["Extend your index finger straight toward the ceiling.", "Curl your middle, ring, and pinky fingers downward.", "Touch your thumb pad to the tips of those three curled fingers."],
     "Confusing D with F (in F, the thumb touches the index finger instead).", "Index finger stands tall like the stem of a lowercase 'd'."),
    ("E", "EE", "static", "All four fingertips curled down tightly to touch the top of your tucked thumb.",
     ["Curl all four fingertips downward tightly.", "Tuck your thumb across your palm directly under the fingertips.", "Ensure your fingertips rest on the side or edge of your thumb."],
     "Confusing E with S (in S, fingers make a closed fist over the thumb).", "Look at the claws of an eagle perched tight."),
    ("F", "EFF", "static", "Index finger and thumb touch to form a circle while middle, ring, and pinky flare upright.",
     ["Touch the pad of your index finger to the tip of your thumb, forming an 'O'.", "Extend your middle, ring, and little fingers straight up and slightly spread.", "Palm faces forward."],
     "Confusing F with D or the OK sign's position.", "F has Three Free Fingers Flying like Feathers."),
    ("G", "JEE", "static", "Index finger and thumb extended horizontally parallel to each other, pointing sideways.",
     ["Curl middle, ring, and pinky fingers against your palm.", "Extend your index finger horizontally pointing across your body.", "Extend your thumb parallel right below the index finger."],
     "Pointing fingers forward instead of horizontally across your chest.", "Measuring the thickness of a Green Grape between thumb and index."),
    ("H", "AYTCH", "static", "Index and middle fingers extended straight horizontally together with thumb tucked underneath.",
     ["Extend index and middle fingers together horizontally pointing sideways.", "Keep thumb tucked flat under your middle finger.", "Palm faces inward toward your chest."],
     "Letting the two fingers split apart (they must stay joined).", "Two horizontal bars like the crossbars of H."),
    ("I", "EYE", "static", "Fist with only the pinky finger extended straight up into the air.",
     ["Make a tight fist with thumb wrapped across your three middle fingers.", "Extend your little finger (pinky) straight upward.", "Palm faces forward toward the viewer."],
     "Letting the thumb poke out or loosening the other three fingers.", "The pinky finger is the tiny vertical line of the letter 'i'."),
    ("J", "JAY", "motion", "Form the 'I' sign with pinky upright, then trace the letter J in the air with a downward curve.",
     ["Start with your hand in the letter 'I' position (pinky extended).", "Dip your hand down and scoop outward in the shape of a fishing hook.", "End with your palm facing toward yourself."],
     "Moving the entire arm rather than initiating from the wrist.", "Your pinky acts as a pen drawing a hook in the air."),
    ("K", "KAY", "static", "Index finger pointing up, middle finger angled forward 45 degrees, thumb resting between them.",
     ["Point index finger straight up.", "Angle your middle finger forward at roughly a 45-degree angle.", "Place your thumb pad right at the crook between index and middle."],
     "Confusing with V (V has both fingers up with no thumb between).", "Fingers create the two angled arms of the letter K."),
    ("L", "ELL", "static", "Index finger pointing up and thumb extended outward at a 90-degree right angle.",
     ["Extend your index finger straight up.", "Stick your thumb out horizontally to the side at 90 degrees.", "Fold the other three fingers flat into your palm."],
     "Pointing thumb down or tilting hand diagonally.", "Your hand forms an unmistakable 'L' shape."),
    ("M", "EM", "static", "Thumb tucked under the first three curled fingers (index, middle, ring).",
     ["Tuck your thumb across your palm.", "Fold index, middle, and ring fingers over top of the thumb.", "Pinky curls into the palm beside them."],
     "Confusing with N (M covers 3 fingers; N covers 2).", "Three fingers over thumb like the three downward humps of an 'm'."),
    ("N", "EN", "static", "Thumb tucked under the first two curled fingers (index and middle).",
     ["Tuck your thumb across your palm.", "Fold only index and middle fingers over the thumb.", "Ring and pinky curl directly into your palm."],
     "Confusing with M or T.", "Two fingers over thumb like the two peaks of an 'n'."),
    ("O", "OH", "static", "All fingers and thumb curve together to touch at the tips, forming an O.",
     ["Curve all four fingers downward together.", "Bring your thumb up to meet all fingertips.", "Create a complete circle viewed from the front."],
     "Flattening the fingers into an oval or pinching too flat.", "Your hand makes a round, hollow 'O'."),
    ("P", "PEE", "static", "The 'K' handshape pointed downwards toward the floor.",
     ["Form the 'K' sign (index up, middle angled, thumb between).", "Tilt your wrist forward so the index finger points downward toward the ground.", "Middle finger extends outward horizontally."],
     "Losing the thumb placement between the two fingers.", "P is simply a dropped, sleepy 'K' pointing to the Pavement."),
    ("Q", "KYOO", "static", "The 'G' handshape turned downwards toward the floor.",
     ["Form the 'G' handshape (index and thumb parallel).", "Point both fingers directly down toward the floor.", "Palm faces slightly toward your body."],
     "Letting other fingers uncurl.", "Q is a G pointing down to Quick sand."),
    ("R", "AHR", "static", "Index and middle fingers crossed tightly together, pointing straight up.",
     ["Extend your index and middle fingers upward.", "Cross your middle finger over in front of your index finger.", "Thumb secures folded ring and pinky fingers."],
     "Crossing the wrong way or separating the fingers.", "Crossing your fingers for good luck (R for Ready)."),
    ("S", "ESS", "static", "Tight fist with the thumb wrapped firmly across the front of all curled fingers.",
     ["Curl all four fingers into a tight fist.", "Wrap your thumb across the middle knuckles of all curled fingers.", "Palm faces forward."],
     "Placing thumb to the side (which is A) instead of across the front.", "Thumb wraps tight like a Snake coiled around your fist."),
    ("T", "TEE", "static", "Thumb tucked between the curled index finger and middle finger.",
     ["Curl all four fingers into your palm.", "Poke your thumb tip up between your index and middle fingers.", "Palm faces forward."],
     "Confusing with M (3 fingers over) or N (2 fingers over). T has only 1 finger over thumb.", "Top of thumb peeking through like a Turtle head."),
    ("U", "YOO", "static", "Index and middle fingers extended straight up and glued together side-by-side.",
     ["Extend your index and middle fingers straight up toward the ceiling.", "Press them firmly together with zero gap between them.", "Fold thumb over ring and pinky fingers."],
     "Allowing a gap between fingers (that makes a V).", "U has the two fingers United together."),
    ("V", "VEE", "static", "Index and middle fingers extended straight up in a separated 'V' shape.",
     ["Extend index and middle fingers upright.", "Spread them apart to form a distinct 'V' or peace sign.", "Thumb secures folded ring and little fingers."],
     "Poking thumb between fingers (which makes a K).", "Classic Victory / Peace sign outlining the letter V."),
    ("W", "DUB-uhl-yoo", "static", "Index, middle, and ring fingers extended upright and spread apart.",
     ["Extend index, middle, and ring fingers straight up.", "Spread all three fingers evenly apart.", "Thumb holds pinky finger down against the palm."],
     "Spreading only two fingers or holding pinky upright.", "Three upright fingers form the three peaks of a 'W'."),
    ("X", "EKS", "static", "Fist with the index finger bent into a curved hook.",
     ["Make a loose fist with your fingers.", "Raise your index finger and bend it at the second knuckle like a hook.", "Palm faces forward or slightly angled."],
     "Curling index completely flat or pointing thumb out.", "A pirate's hook marking the spot where X marks the treasure."),
    ("Y", "WY", "static", "Fist with thumb and pinky extended outward like a 'hang loose' sign.",
     ["Curl middle three fingers firmly into your palm.", "Extend your thumb out to one side and your pinky out to the other.", "Palm faces forward."],
     "Angling hand horizontally instead of keeping palm upright.", "The classic 'shaka' or phone gesture outlining the two branches of Y."),
    ("Z", "ZED", "motion", "Index finger extended, drawing a 'Z' shape across the air in front of you.",
     ["Make a fist with your index finger pointing forward like a pencil.", "Trace a horizontal line left to right.", "Diagonal down-left, then horizontal left to right to draw a Z."],
     "Moving whole body instead of using a crisp wrist motion.", "Zorro carving his famous 'Z' with a single finger stroke.")
]

# Numbers 1-10
NUMBERS_DATA = [
    ("1", "ONE", "static", "Index finger held upright with palm facing inward toward yourself.",
     ["Make a fist with your dominant hand.", "Extend your index finger straight up.", "Face your palm backward toward your own chest/face."],
     "Facing palm outward (that represents the letter D in fingerspelling).", "Single tall candle."),
    ("2", "TWO", "static", "Index and middle fingers held upright together or slightly spread, palm facing inward.",
     ["Extend index and middle fingers upward.", "Keep palm facing inward toward your body.", "Thumb holds ring and pinky fingers."],
     "Facing palm outward (which is letter V).", "Two eyes looking back at you."),
    ("3", "THREE", "static", "Thumb, index, and middle fingers extended with palm facing inward.",
     ["Extend your thumb, index finger, and middle finger.", "Keep ring and pinky fingers folded into your palm.", "Palm faces inward toward yourself."],
     "Using index, middle, and ring fingers (that is British sign or European count, not ASL!).", "ASL 3 always includes the thumb!"),
    ("4", "FOUR", "static", "All four fingers held upright and slightly spread, thumb tucked across palm.",
     ["Extend four fingers upward.", "Fold thumb flat against the palm.", "Palm faces inward toward your chest."],
     "Spreading fingers too wide.", "Four fence posts stood tall."),
    ("5", "FIVE", "static", "All five fingers extended and spread wide, palm facing inward.",
     ["Extend all five fingers and thumb.", "Spread them comfortably apart.", "Hold at chest height with palm facing inward."],
     "Facing palm outward.", "Open high-five hand turned inward."),
    ("6", "SIX", "static", "Thumb and pinky tips touch forming a circle, three middle fingers held upright.",
     ["Hold hand upright with palm facing forward.", "Bring the tip of your thumb to touch the tip of your pinky finger.", "Extend index, middle, and ring fingers straight up."],
     "Touching the wrong finger (touching index is 9; touching middle is 8; touching ring is 7).", "Smallest finger (pinky) starts the higher numbers: 6."),
    ("7", "SEVEN", "static", "Thumb and ring fingertip touch, while index, middle, and pinky stay upright.",
     ["Hold hand upright with palm facing outward.", "Touch your thumb pad to your ring fingertip.", "Keep index, middle, and little finger upright."],
     "Touching pinky instead of ring finger.", "Ring finger count down."),
    ("8", "EIGHT", "static", "Thumb and middle fingertip touch, while other three fingers stay upright.",
     ["Hold hand upright with palm facing outward.", "Touch your thumb pad to your middle fingertip.", "Index, ring, and pinky remain extended upright."],
     "Touching ring finger instead of middle finger.", "Middle finger connection."),
    ("9", "NINE", "static", "Thumb and index fingertip touch (like OK sign), other three fingers upright.",
     ["Hold hand upright with palm facing forward.", "Touch your thumb pad to your index fingertip forming an 'O'.", "Keep middle, ring, and pinky fingers extended upward."],
     "Confusing with letter F (F is a letter; 9 is signed identically in shape with neutral context).", "Nine is fine like an OK sign."),
    ("10", "TEN", "motion", "Thumbtack fist with thumb upright, shaken or rotated side to side twice.",
     ["Make a fist with your thumb extended straight up (like a thumbs up).", "Hold at shoulder level with palm facing inward/forward.", "Rotate your wrist side-to-side in a small shaking motion twice."],
     "Over-rotating the arm or shaking the whole elbow.", "Thumbs up shaking with excitement for a perfect 10.")
]

# Vocabulary Words (~60 words) across 9 Prototype Categories
VOCABULARY_DATA = [
    # GREETINGS
    ("Hello", "HEH-loh", "greetings", "beginner", "Top 10", "one_handed", "motion",
     "A friendly salute gesture moving away from your forehead.",
     ["Place the flat side of your dominant open hand near your temple (like a salute).", "Move your hand forward and outward away from your forehead with a gentle, smooth arc.", "Smile and make friendly eye contact."],
     "Don't flick your hand too abruptly or touch your forehead too roughly.", "A warm military salute to a friend.",
     "cat_greetings_intro", "video_hello_front", "video_hello_side"),
    ("Good Morning", "good MOR-ning", "greetings", "beginner", "Essential", "two_handed", "motion",
     "Compound sign: 'Good' followed by the sun rising over the horizon arm.",
     ["Sign 'Good': touch chin with flat hand and bring down to resting palm.", "Extend non-dominant arm horizontally across body as the horizon.", "Dominant hand rises upward from behind the arm like the morning sun."],
     "Rushing the two signs together without distinct articulation.", "The sun rising up into a beautiful day.",
     None, "video_goodmorning_front", "video_goodmorning_side"),
    ("Good Night", "good NYT", "greetings", "beginner", "Essential", "two_handed", "motion",
     "Compound sign: 'Good' followed by the sun dropping below the horizon.",
     ["Sign 'Good' from chin to non-dominant palm.", "Rest non-dominant arm horizontally.", "Dominant curved hand scoops downward over the arm like the sun setting into sleep."],
     "Curving the hand upward instead of dropping down.", "The sun dipping below the bed horizon.",
     None, "video_goodnight_front", "video_goodnight_side"),
    ("Goodbye", "good-BYE", "greetings", "beginner", "Top 10", "one_handed", "motion",
     "Open flat hand waving fingers open and closed from the knuckles.",
     ["Raise open flat hand to shoulder height, palm facing outward.", "Fold fingers downward toward palm together twice in a warm wave.", "Keep wrist relatively stationary."],
     "Waving side to side like a windshield wiper.", "A classic gentle farewell wave.",
     None, "video_goodbye_front", "video_goodbye_side"),
    ("Welcome", "WEL-kum", "greetings", "beginner", "Common", "one_handed", "motion",
     "Open curved hand sweeping inward toward your body with an inviting motion.",
     ["Extend dominant open hand outward, palm tilted up.", "Sweep your hand in an arc toward your torso invitingly.", "Nod gently with a warm welcoming expression."],
     "Starting too close to your chest.", "Sweeping your hand as if gesturing 'come on in!'",
     None, "video_welcome_front", "video_welcome_side"),
    ("How are you", "how ahr YOO", "greetings", "beginner", "Essential", "two_handed", "motion",
     "Curved hands with backs together rolling upward, then pointing forward to the person.",
     ["Place knuckles of both curved hands together facing down.", "Roll hands upward and outward so palms face up.", "Point index finger forward at the conversation partner ('you')."],
     "Forgetting the facial expression (furrow brow slightly for an inquiry).", "Opening up your hands to ask how someone's heart is.",
     None, "video_howareyou_front", "video_howareyou_side"),
    ("Nice to meet you", "nys too MEET yoo", "greetings", "beginner", "Essential", "two_handed", "motion",
     "Compound sign: 'Nice' (palms slide flat) + 'Meet' (two index fingers meet in center).",
     ["Slide dominant palm forward across flat non-dominant palm ('Nice').", "Bring both index fingers upright together until knuckles touch ('Meet').", "Point index finger forward to 'You'."],
     "Bumping fingers too aggressively.", "Two people walking toward each other to greet.",
     None, "video_nicetomeetyou_front", "video_nicetomeetyou_side"),

    # COURTESY
    ("Please", "PLEEZ", "courtesy", "beginner", "Top 10", "one_handed", "motion",
     "Flat open hand rubbing in a gentle clockwise circle over your chest.",
     ["Place your dominant open flat hand flat against the center of your chest.", "Rub in circular, clockwise motions twice with fingers together.", "Wear a polite, sincere facial expression."],
     "Making circles in the air without touching your chest.", "Rubbing your heart to show your polite intentions.",
     None, "video_please_front", "video_please_side"),
    ("Thank You", "THANGK yoo", "courtesy", "beginner", "Top 10", "one_handed", "motion",
     "Fingertips touch chin or lips and extend outward toward the person with a nod.",
     ["Touch the fingertips of your flat open dominant hand to your chin or lower lip.", "Move your hand smoothly forward and slightly down toward the other person.", "Keep palm facing upward toward them."],
     "Do not blow a kiss or curl your fingers; keep palm open and respectful.", "Sending gratitude directly from your lips to them.",
     None, "video_thankyou_front", "video_thankyou_side"),
    ("Sorry", "SAHR-ee", "courtesy", "beginner", "Top 10", "one_handed", "motion",
     "'A' fist circling gently over the heart on your chest.",
     ["Make an 'A' or 'S' fist with your dominant hand.", "Place the knuckles flat against the center of your chest over your heart.", "Rub in small circular motions twice with an apologetic expression."],
     "Using an open hand (which means Please) instead of a closed fist.", "Grinding your fist over a bruised, sorry heart.",
     None, "video_sorry_front", "video_sorry_side"),
    ("Excuse Me", "ek-SKYOOZ mee", "courtesy", "beginner", "Common", "two_handed", "motion",
     "Dominant curved fingertips gently brushing across flat non-dominant palm twice.",
     ["Hold non-dominant hand flat, palm facing up.", "Curve dominant fingers like a rake and brush across non-dominant palm forward twice.", "Tilt head with an inquisitive polite expression."],
     "Scraping too hard or brushing backwards.", "Gently sweeping away an obstacle to pass by.",
     None, "video_excuseme_front", "video_excuseme_side"),
    ("You're Welcome", "yor WEL-kum", "courtesy", "beginner", "Common", "one_handed", "motion",
     "Open hand nodding down or signing Welcome / Thank you back.",
     ["Dominant open hand moves down in a polite nod or welcoming sweep.", "Often signed by nodding with a polite smile, or signing 'Thank you' in return."],
     "Overcomplicating the gesture; in ASL, a warm head nod and open hand is natural.", "Accepting gratitude gracefully.",
     None, "video_yourewelcome_front", "video_yourewelcome_side"),
    ("Good", "GOOD", "courtesy", "beginner", "Top 10", "two_handed", "motion",
     "Fingertips touch chin and fall down into the waiting non-dominant palm.",
     ["Touch flat dominant fingertips to your chin.", "Bring hand down to land gently on the upturned palm of your non-dominant hand.", "Smile with satisfaction."],
     "Confusing with Thank You (Good lands on the other hand; Thank You moves into empty space).", "Tasting something good and laying it gently in your hand.",
     None, "video_good_front", "video_good_side"),
    ("Bad", "BAD", "courtesy", "beginner", "Common", "one_handed", "motion",
     "Fingertips touch chin and flip forcefully downward away with palm facing down.",
     ["Touch flat fingertips to your chin.", "Flip your hand downward and outward with palm facing down toward the floor.", "Grimace slightly or shake head to show disapproval."],
     "Dropping hand straight down without the downward flip.", "Spitting out something bad from your chin.",
     None, "video_bad_front", "video_bad_side"),

    # EVERYDAY
    ("Yes", "YES", "everyday", "beginner", "Top 10", "one_handed", "motion",
     "'S' fist nodding up and down from the wrist like a head nodding.",
     ["Make an 'S' fist with your dominant hand held at chest height.", "Nod your fist up and down twice bending only at the wrist.", "Affirm with a gentle head nod."],
     "Pumping your whole arm up and down from the elbow.", "Your fist represents a head nodding in agreement.",
     None, "video_yes_front", "video_yes_side"),
    ("No", "NOH", "everyday", "beginner", "Top 10", "one_handed", "motion",
     "Index and middle fingers snap down quickly onto the thumb pad.",
     ["Hold index and middle fingers extended forward with thumb below them.", "Snap the two fingers down firmly onto the thumb pad once or twice.", "Shake your head slightly."],
     "Snapping only the index finger (must use both index and middle).", "A firm mouth snapping shut saying 'No!'",
     None, "video_no_front", "video_no_side"),
    ("Maybe", "MAY-bee", "everyday", "beginner", "Common", "two_handed", "motion",
     "Both flat hands palms up rocking alternately up and down like scales.",
     ["Hold both open flat hands in front of you with palms facing up.", "Alternate raising one hand while lowering the other, like balancing scales.", "Tilt head and shrug shoulders."],
     "Moving hands in unison instead of alternating.", "Weighing two possibilities on a balance scale.",
     None, "video_maybe_front", "video_maybe_side"),
    ("Name", "NAYM", "everyday", "beginner", "Essential", "two_handed", "motion",
     "'H' handshapes tapped across each other twice at right angles.",
     ["Form 'H' with both hands (index and middle fingers extended together).", "Tap the dominant fingers across the non-dominant fingers twice in an 'X' cross.", "Keep wrists steady."],
     "Tapping with single index fingers (which is the sign for Needle or Hurt).", "Carving your mark or signature on a wooden plaque.",
     None, "video_name_front", "video_name_side"),
    ("Deaf", "DEF", "everyday", "beginner", "Essential", "one_handed", "motion",
     "Index finger touches near the ear then moves forward to touch near the mouth.",
     ["Extend index finger pointing up.", "Touch fingertip near your ear lobe, then arc forward to touch the corner of your mouth.", "Can also be signed mouth-to-ear."],
     "Touching cheek instead of ear/mouth alignment.", "Connecting the ear and mouth in proud Deaf culture.",
     None, "video_deaf_front", "video_deaf_side"),
    ("Hearing", "HEER-ing", "everyday", "beginner", "Essential", "one_handed", "motion",
     "Index finger rolling in small forward circles horizontally in front of the mouth.",
     ["Hold index finger horizontally in front of your lips.", "Roll finger in small forward circular motions toward the listener.", "Neutral or conversational facial expression."],
     "Making circles around the ear (that is 'Listen' or 'Hear').", "Words continually rolling out of a hearing person's mouth.",
     None, "video_hearing_front", "video_hearing_side"),
    ("Sign", "SYN", "everyday", "beginner", "Essential", "two_handed", "motion",
     "Both index fingers circling backward toward your chest in alternating rhythm.",
     ["Point both index fingers inward toward each other at chest height.", "Roll both hands in backward circles alternately, gesturing fluid movement.", "Engage your upper body naturally."],
     "Circling forward away from body (forward circling is 'Argue' or 'Converse').", "Hands dancing in rhythm with the language of signs.",
     None, "video_sign_front", "video_sign_side"),
    ("Friend", "FREND", "everyday", "beginner", "Essential", "two_handed", "motion",
     "Index fingers hooked into each other, then reversed and hooked again.",
     ["Hook dominant index finger over non-dominant index finger.", "Unlink, flip hands, and hook them in the reverse direction.", "Smile warmly."],
     "Holding fingers straight instead of curved hooks.", "Two lives closely intertwined and linked together.",
     None, "video_friend_front", "video_friend_side"),
    ("Time", "TYM", "everyday", "beginner", "Common", "two_handed", "motion",
     "Dominant index finger tapping the wrist of the non-dominant hand twice.",
     ["Hold non-dominant wrist still in front of chest.", "Tap dominant index finger twice on the top of your wrist where a watch sits.", "Inquire with raised eyebrows if asking 'What time?'"],
     "Tapping the inner wrist instead of the outer watch face.", "Tapping a wristwatch to check the hour.",
     None, "video_time_front", "video_time_side"),
    ("Today", "tuh-DAY", "everyday", "beginner", "Common", "two_handed", "motion",
     "'Y' handshapes dropped downward together twice in front of you.",
     ["Form 'Y' handshapes with both hands (thumb and pinky out).", "Drop both hands downward smoothly twice in front of your waist.", "Can also sign 'Now' + 'Day'."],
     "Moving hands outward instead of straight down.", "Dropping anchor right here into today.",
     None, "video_today_front", "video_today_side"),
    ("Tomorrow", "tuh-MAHR-oh", "everyday", "beginner", "Common", "one_handed", "motion",
     "'A' fist with thumb touching chin, then rotating forward into the future.",
     ["Place thumb of 'A' fist against your dominant jaw or cheek.", "Rotate wrist forward and arc your hand ahead into the space in front of you.", "Keep movement fluid."],
     "Starting too far forward on the lips.", "Looking forward past the sunrise into tomorrow.",
     None, "video_tomorrow_front", "video_tomorrow_side"),

    # FAMILY
    ("Mother", "MUH-ther", "family", "beginner", "Essential", "one_handed", "motion",
     "Open '5' hand with thumb tapping the chin twice.",
     ["Spread all five fingers of dominant hand wide.", "Tap the tip of your thumb gently against your chin twice.", "Warm, gentle expression."],
     "Tapping forehead instead of chin (forehead is Father!).", "Female signs in ASL are positioned on the lower face / chin line.",
     None, "video_mother_front", "video_mother_side"),
    ("Father", "FAH-ther", "family", "beginner", "Essential", "one_handed", "motion",
     "Open '5' hand with thumb tapping the forehead twice.",
     ["Spread all five fingers wide with palm facing sideways/forward.", "Tap thumb tip against the side of your forehead twice.", "Keep hand steady."],
     "Tapping chin (chin is Mother!).", "Male signs in ASL are positioned on the upper face / forehead (resembling a cap brim).",
     None, "video_father_front", "video_father_side"),
    ("Brother", "BRUH-ther", "family", "intermediate", "Common", "two_handed", "motion",
     "'L' or '1' handshape from forehead coming down to rest on non-dominant index finger.",
     ["Dominant 'L' hand touches forehead (male sign).", "Brings down to clasp over non-dominant '1' hand waiting in front of chest.", "Firm, clean motion."],
     "Starting on the chin (that would be Sister!).", "A male child born from the same family line.",
     None, "video_brother_front", "video_brother_side"),
    ("Sister", "SIS-ter", "family", "intermediate", "Common", "two_handed", "motion",
     "'L' handshape from jawline coming down to rest on non-dominant index finger.",
     ["Dominant 'L' thumb strokes side of chin/jaw (female sign).", "Brings down to rest directly on non-dominant index finger at chest level.", "Smooth connection."],
     "Starting on the forehead (that is Brother!).", "A female sibling born from the same line.",
     None, "video_sister_front", "video_sister_side"),
    ("Baby", "BAY-bee", "family", "beginner", "Common", "two_handed", "motion",
     "Cradling arms rocking side to side as if holding an infant.",
     ["Cross both forearms in front of chest, dominant arm over non-dominant.", "Cup hands as if cradling a newborn baby.", "Rock arms gently side to side twice."],
     "Rocking too fast or jerky; keep it tender and natural.", "Cradling an infant in your arms.",
     None, "video_baby_front", "video_baby_side"),
    ("Family", "FAM-uh-lee", "family", "intermediate", "Essential", "two_handed", "motion",
     "Both 'F' hands starting with index/thumbs touching, circling out and joining pinkies.",
     ["Form 'F' with both hands, touching index/thumb rings in front of chest.", "Circle both hands outward and forward away from each other.", "Complete circle by bringing little fingers together."],
     "Starting with pinkies touching instead of index rings.", "Drawing a closed protective circle around the family unit.",
     None, "video_family_front", "video_family_side"),
    ("Son", "SUN", "family", "intermediate", "Common", "two_handed", "motion",
     "Salute from forehead, then cradling into baby position in arms.",
     ["Salute from forehead with open hand (male indicator).", "Bring hand down into arms cradled like an infant.", "Smooth transition."],
     "Starting from chin.", "A baby boy born into your arms.",
     None, "video_son_front", "video_son_side"),
    ("Daughter", "DAW-ter", "family", "intermediate", "Common", "two_handed", "motion",
     "Stroke jawline from ear to chin, then cradle into baby position.",
     ["Dominant open hand strokes jawline forward (female indicator).", "Bring hand down into cradled arms.", "Gentle motion."],
     "Starting from forehead.", "A baby girl welcomed into your family.",
     None, "video_daughter_front", "video_daughter_side"),
    ("Grandmother", "GRAND-muh-ther", "family", "intermediate", "Common", "one_handed", "motion",
     "Sign 'Mother' at chin, then bounce hand forward in two small arcs.",
     ["Place thumb of open '5' hand on chin.", "Bounce hand forward in two gentle arcs outward away from face.", "Signifies one generation removed."],
     "Only one arc (single arc is sometimes confused with talking).", "Mother plus one generation forward in time.",
     None, "video_grandmother_front", "video_grandmother_side"),
    ("Grandfather", "GRAND-fah-ther", "family", "intermediate", "Common", "one_handed", "motion",
     "Sign 'Father' at forehead, then bounce hand forward in two small arcs.",
     ["Place thumb of open '5' hand on forehead.", "Bounce hand forward in two arcs outward away from face.", "Keep fingers spread."],
     "Dropping down to chin.", "Father plus one generation forward in time.",
     None, "video_grandfather_front", "video_grandfather_side"),

    # FEELINGS
    ("Happy", "HAP-ee", "feelings", "beginner", "Top 10", "one_handed", "motion",
     "Open flat hand brushing upward against chest twice with an energetic smile.",
     ["Place flat dominant hand against chest, palm facing in.", "Brush hand upward toward chin twice in quick, uplifting motions.", "Smile brightly with cheerful eyes."],
     "Brushing downward (downward signifies depression or sad).", "Joy bubbling up inside your chest and overflowing.",
     None, "video_happy_front", "video_happy_side"),
    ("Sad", "SAD", "feelings", "beginner", "Top 10", "one_handed", "motion",
     "Open curved fingers in front of face dropping downward while tilting head down.",
     ["Hold open hand in front of face with curved drooping fingers.", "Slowly drop hand downward toward chest while dropping your head.", "Expression should look sorrowful and heavy."],
     "Smiling or moving too quickly.", "Tears or sorrow pulling the whole face down.",
     None, "video_sad_front", "video_sad_side"),
    ("Angry", "ANG-gree", "feelings", "beginner", "Common", "one_handed", "motion",
     "Clawed hand placed near face pulling outward forcefully with an intense expression.",
     ["Form a claw with dominant hand in front of nose/face.", "Pull hand forward and out quickly as if ripping off a mask.", "Furrow brow and show stern anger."],
     "Smiling breaks the sign completely; facial grammar is essential.", "Claws of fiery anger tearing outward.",
     None, "video_angry_front", "video_angry_side"),
    ("Tired", "TYRD", "feelings", "beginner", "Common", "two_handed", "motion",
     "Curved fingertips placed on chest, rolling inward and dropping down as shoulders slump.",
     ["Place curved fingertips of both hands on respective sides of upper chest.", "Roll hands down and inward so wrists drop.", "Exhale and slump shoulders with fatigue."],
     "Keeping shoulders rigid.", "The energy literally draining from your torso.",
     None, "video_tired_front", "video_tired_side"),
    ("Excited", "ek-SY-ted", "feelings", "intermediate", "Common", "two_handed", "motion",
     "Middle fingers bent forward at knuckles, circling alternately up across chest.",
     ["Bend middle fingers forward from open hands.", "Alternate flicking/circling middle fingertips upward across chest.", "Bright animated eyes and smile."],
     "Using flat fingers instead of feeling middle fingers.", "Heart fluttering rapidly with excitement.",
     None, "video_excited_front", "video_excited_side"),
    ("Scared", "SKAIRD", "feelings", "beginner", "Common", "two_handed", "motion",
     "Open hands crossing in front of chest in a sudden defensive trembling motion.",
     ["Bring open hands in from sides toward chest, fingers pointing toward each other.", "Make a quick shivering or shaking motion in front of heart.", "Widen eyes with fear."],
     "Slow motion; must be snappy and sudden.", "Instinctively protecting your vital organs from fright.",
     None, "video_scared_front", "video_scared_side"),
    ("Fine", "FYN", "feelings", "beginner", "Common", "one_handed", "motion",
     "Open '5' hand with thumb tapping chest twice with relaxed posture.",
     ["Open '5' hand with thumb touching the center of your sternum.", "Tap thumb against chest twice with calm, relaxed rhythm.", "Casual polite smile."],
     "Stiff fingers; keep it light.", "Everything is balanced and fine at your core.",
     None, "video_fine_front", "video_fine_side"),
    ("Confused", "kun-FYOOZD", "feelings", "intermediate", "Common", "two_handed", "motion",
     "Index finger points to forehead (think), followed by claw hands scrambling over each other.",
     ["Touch temple with index finger ('Think').", "Lower hands to chest with claw fingers twisting and scrambling around each other.", "Squint eyes and furrow brow."],
     "Forgetting the initial forehead touch.", "Thoughts getting tangled like spaghetti in your mind.",
     None, "video_confused_front", "video_confused_side"),
    ("Love", "LUV", "feelings", "beginner", "Top 10", "two_handed", "static",
     "Both hands folded into 'S' fists crossed over the heart in a hug.",
     ["Cross both arms over your chest, placing fists over heart.", "Hold firmly against body with a warm affectionate expression.", "Can tilt head slightly."],
     "Crossing hands at the wrists only; hugs should cover the chest.", "A full, warm embrace wrapped around your heart.",
     None, "video_love_front", "video_love_side"),

    # FOOD & DRINK
    ("Water", "WAH-ter", "food-drink", "beginner", "Top 10", "one_handed", "motion",
     "'W' handshape with index finger tapping the lips twice.",
     ["Form 'W' handshape with index, middle, and ring fingers extended.", "Tap the side of your index finger against your chin/lower lip twice.", "Keep palm facing left/sideways."],
     "Tapping cheek instead of lips.", "W stands for Water at your lips.",
     None, "video_water_front", "video_water_side"),
    ("Food", "FOOD", "food-drink", "beginner", "Top 10", "one_handed", "motion",
     "Flattened 'O' handshape tapping the lips twice.",
     ["Pinch all fingertips to thumb in a squashed 'O' (like holding a bite of food).", "Tap fingertips against lips twice.", "Neutral or hungry expression."],
     "Tapping only once (single tap is the verb 'Eat'; double tap is the noun 'Food').", "Putting morsels of food into your mouth.",
     None, "video_food_front", "video_food_side"),
    ("Eat", "EET", "food-drink", "beginner", "Top 10", "one_handed", "motion",
     "Flattened 'O' handshape brought to mouth in a single feeding motion.",
     ["Pinch fingertips to thumb.", "Bring hand to lips once smoothly.", "Mouth the word 'Eat'."],
     "Tapping multiple times (that is Food).", "Single bite into mouth.",
     None, "video_eat_front", "video_eat_side"),
    ("Drink", "DRINGK", "food-drink", "beginner", "Top 10", "one_handed", "motion",
     "'C' handshape tipped back toward open mouth like drinking from a cup.",
     ["Form 'C' handshape as if holding an invisible glass.", "Tip thumb and cup toward mouth, tilting head back slightly.", "Simulate a sip."],
     "Spilling the invisible cup past your mouth.", "Drinking from a glass.",
     None, "video_drink_front", "video_drink_side"),
    ("Milk", "MILK", "food-drink", "beginner", "Common", "one_handed", "motion",
     "Squeezing fist open and closed twice as if milking a cow.",
     ["Hold fist out in front of chest.", "Squeeze fingers open and closed twice firmly.", "Keep wrist steady."],
     "Using two hands (usually done with one hand).", "Milking an udder on a farm.",
     None, "video_milk_front", "video_milk_side"),
    ("Bread", "BRED", "food-drink", "intermediate", "Common", "two_handed", "motion",
     "Curved dominant fingers slicing downward along the back of non-dominant hand.",
     ["Hold non-dominant arm across chest as a loaf.", "Use dominant fingertips like a knife slicing down the back of the hand twice.", "Even slices."],
     "Chopping flat instead of curved slice.", "Slicing fresh bread off the loaf.",
     None, "video_bread_front", "video_bread_side"),
    ("Apple", "AP-uhl", "food-drink", "intermediate", "Common", "one_handed", "motion",
     "Knuckle of dominant 'X' twisting twice into the cheek.",
     ["Make an 'X' with index knuckle bent.", "Press knuckle into your cheek and twist wrist back and forth twice.", "Slight smile."],
     "Using fingertip instead of the knuckle.", "Twisting an apple stem to pick it from the branch.",
     None, "video_apple_front", "video_apple_side"),
    ("Coffee", "KAW-fee", "food-drink", "intermediate", "Common", "two_handed", "motion",
     "Dominant fist grinding in circles on top of stationary non-dominant fist.",
     ["Hold non-dominant fist still.", "Place dominant fist directly on top and rotate in circular grinding motion.", "Like an antique hand grinder."],
     "Moving bottom fist.", "Grinding roasted coffee beans.",
     None, "video_coffee_front", "video_coffee_side"),
    ("Tea", "TEE", "food-drink", "intermediate", "Common", "two_handed", "motion",
     "'F' handshape dipping into the 'O' rim of the non-dominant hand like a tea bag.",
     ["Make a cup rim with non-dominant 'O' or 'C'.", "Hold 'F' hand with dominant hand and dip into the cup twice.", "Delicate motion."],
     "Stirring vigorously (stirring is a soup gesture).", "Steeping a tea bag into hot water.",
     None, "video_tea_front", "video_tea_side"),
    ("Hungry", "HUNG-gree", "food-drink", "beginner", "Common", "one_handed", "motion",
     "'C' handshape sliding downward from throat down to sternum.",
     ["Place 'C' handshape at center of throat.", "Slide hand straight down to stomach.", "Expression showing an empty belly."],
     "Bouncing hand; must slide straight down.", "Empty channel running through the stomach.",
     None, "video_hungry_front", "video_hungry_side"),
    ("Thirsty", "THUR-stee", "food-drink", "beginner", "Common", "one_handed", "motion",
     "Index finger tracing a line straight down the center of the throat.",
     ["Point index finger to throat.", "Draw line straight down toward chest.", "Dry mouth expression."],
     "Curving finger; keep it straight and direct.", "Tracing a dry throat in need of water.",
     None, "video_thirsty_front", "video_thirsty_side"),

    # HEALTHCARE
    ("Pain", "PAYN", "healthcare", "beginner", "Essential", "two_handed", "motion",
     "Both index fingers pointed at each other, twisting inward toward each other with a wince.",
     ["Point both index fingers toward each other horizontally.", "Jab inward toward each other twice with a twisting motion.", "Wince with pain."],
     "Touching fingers completely (keep a small gap).", "Sign where the pain hurts (e.g. at head for headache).",
     None, "video_pain_front", "video_pain_side"),
    ("Sick", "SIK", "healthcare", "beginner", "Essential", "two_handed", "static",
     "Middle finger of dominant hand on forehead, middle finger of non-dominant hand on stomach.",
     ["Bend middle fingers forward from open hands.", "Place one on forehead, one on stomach simultaneously.", "Sick facial expression."],
     "Using index finger instead of middle feeling finger.", "Fever in head, nausea in stomach.",
     None, "video_sick_front", "video_sick_side"),
    ("Fever", "FEE-ver", "healthcare", "intermediate", "Common", "one_handed", "motion",
     "Back of dominant hand touching forehead repeatedly as if feeling temperature.",
     ["Place back of open dominant hand against forehead.", "Feel temperature with serious concerned expression.", "Can puff cheeks."],
     "Touching with palm (mothers feel fever with the sensitive back of hand).", "Testing for a hot forehead.",
     None, "video_fever_front", "video_fever_side"),
    ("Doctor", "DAHK-ter", "healthcare", "beginner", "Essential", "two_handed", "motion",
     "'D' or 'M' fingertips tapping the inner wrist of non-dominant hand twice.",
     ["Hold non-dominant wrist with palm up.", "Tap fingertips of dominant hand on radial pulse twice.", "Professional posture."],
     "Tapping back of hand.", "Doctor taking your pulse.",
     None, "video_doctor_front", "video_doctor_side"),
    ("Nurse", "NURS", "healthcare", "intermediate", "Common", "two_handed", "motion",
     "'N' fingertips tapping the radial pulse on the inner wrist twice.",
     ["Hold non-dominant wrist upturned.", "Tap 'N' handshape fingertips on the pulse.", "Gentle professional touch."],
     "Using three fingers (that would be 'M' / Doctor variant).", "N for Nurse feeling the pulse.",
     None, "video_nurse_front", "video_nurse_side"),
    ("Appointment", "uh-POYNT-ment", "healthcare", "intermediate", "Common", "two_handed", "motion",
     "Dominant hand circling in air and coming down firmly onto non-dominant fist.",
     ["Hold non-dominant fist still.", "Circle dominant curved hand over it and land firmly on top.", "Locking in a date."],
     "Loose landing; must be decisive.", "Locking down a scheduled time.",
     None, "video_appointment_front", "video_appointment_side"),
    ("Headache", "HED-ayk", "healthcare", "beginner", "Common", "two_handed", "motion",
     "Sign 'Pain' with both index fingers jabbing inward at the temples.",
     ["Hold index fingers pointing toward temples.", "Twist inward toward head twice with squinted eyes in pain.", "Visible discomfort."],
     "Jabbing chest (that is chest pain).", "Throbbing ache across the temples.",
     None, "video_headache_front", "video_headache_side"),

    # WORKPLACE
    ("Work", "WURK", "workplace", "beginner", "Essential", "two_handed", "motion",
     "Dominant fist tapping the wrist of non-dominant fist twice.",
     ["Hold non-dominant fist with palm down.", "Tap base of dominant fist over the back of the wrist twice.", "Steady, productive tempo."],
     "Tapping palms together.", "Hard work chipping away at a stone anvil.",
     None, "video_work_front", "video_work_side"),
    ("Meeting", "MEE-ting", "workplace", "intermediate", "Common", "two_handed", "motion",
     "Both open hands coming together and closing into flat 'O's facing each other.",
     ["Start with hands wide and open facing each other.", "Bring hands together into center, folding fingers into 'O's like people gathering.", "Group gathering."],
     "Not closing fingers into O shape.", "People assembling around a conference table.",
     None, "video_meeting_front", "video_meeting_side"),
    ("Office", "AW-fis", "workplace", "intermediate", "Common", "two_handed", "motion",
     "'O' handshapes outlining the four walls of a room.",
     ["Form 'O' with both hands.", "Show front and back walls, then turn hands to show side walls.", "Enclosing a space."],
     "Only showing two sides.", "O for Office outlining a room.",
     None, "video_office_front", "video_office_side"),
    ("Boss", "BAWS", "workplace", "intermediate", "Common", "one_handed", "motion",
     "Clawed hand tapping the dominant shoulder twice.",
     ["Make a claw with dominant hand.", "Tap fingertips against dominant shoulder twice.", "Assertive posture."],
     "Tapping chest instead of shoulder.", "The weight of epaulettes / authority on the shoulder.",
     None, "video_boss_front", "video_boss_side"),
    ("Email", "EE-mayl", "workplace", "beginner", "Common", "two_handed", "motion",
     "Dominant index finger shooting through the 'C' tunnel of non-dominant hand.",
     ["Form a horizontal tube with non-dominant 'C'.", "Shoot dominant index finger straight through the tunnel forward.", "Quick zippy motion."],
     "Missing the tunnel.", "An electronic letter shooting through the cable.",
     None, "video_email_front", "video_email_side"),
    ("Break", "BRAYK", "workplace", "beginner", "Common", "two_handed", "motion",
     "Flat dominant hand chopping down between index and middle fingers of non-dominant hand.",
     ["Spread index and middle fingers of non-dominant hand.", "Chop dominant flat hand down into the space between them.", "Relaxing sigh."],
     "Chopping whole arm.", "Taking a distinct break in the schedule.",
     None, "video_break_front", "video_break_side"),
    ("Project", "PRAH-jekt", "workplace", "intermediate", "Common", "two_handed", "motion",
     "'P' hand touching non-dominant palm, then moving to touch with 'J'.",
     ["Touch base of palm with 'P'.", "Arc up and trace down with 'J'.", "Or initialize P across paper."],
     "Sloppy letters.", "P to J initials outlining a project dossier.",
     None, "video_project_front", "video_project_side"),
    ("Schedule", "SKEJ-ool", "workplace", "intermediate", "Common", "two_handed", "motion",
     "Four fingers of dominant hand drawing a vertical then horizontal grid across non-dominant palm.",
     ["Hold non-dominant palm flat facing you.", "Draw four dominant fingers down across palm, then across horizontally.", "Like a calendar grid."],
     "Only one stroke.", "Drawing calendar rows and columns.",
     None, "video_schedule_front", "video_schedule_side"),

    # EMERGENCY
    ("Help", "HELP", "emergency", "beginner", "Essential", "two_handed", "motion",
     "Dominant 'thumbs up' fist resting on flat non-dominant palm, lifted upward together.",
     ["Place dominant fist with thumb up flat onto open palm of non-dominant hand.", "Lift both hands upward together decisively.", "Urgent or supportive expression."],
     "Not lifting; the upward hoist represents giving support.", "Lifting someone up when they cannot stand on their own.",
     None, "video_help_front", "video_help_side"),
    ("Emergency", "ee-MUR-jen-see", "emergency", "beginner", "Essential", "one_handed", "motion",
     "'E' handshape waving rapidly side to side with urgency.",
     ["Form an 'E' handshape with dominant hand.", "Shake it briskly side to side at chest height with an alert face.", "Wide alert eyes."],
     "Sluggish movement; must convey alarm.", "Emergency flashing like an alarm light.",
     None, "video_emergency_front", "video_emergency_side"),
    ("Hospital", "HAHS-pi-tul", "emergency", "beginner", "Essential", "one_handed", "motion",
     "'H' hand drawing a cross on the upper non-dominant arm.",
     ["Form 'H' with index and middle fingers together.", "Draw a cross on the upper bicep of your other arm (vertical stroke, then horizontal).", "Solemn expression."],
     "Drawing on chest (cross on chest is church/religion; on arm is hospital/Red Cross).", "The Red Cross emblem on a doctor's sleeve.",
     None, "video_hospital_front", "video_hospital_side"),
    ("Police", "puh-LEES", "emergency", "beginner", "Essential", "one_handed", "motion",
     "'C' handshape tapped twice on the chest over the badge area.",
     ["Form a 'C' handshape.", "Tap it twice over your left chest where a badge is pinned.", "Official demeanor."],
     "Tapping right shoulder.", "Tapping a police officer's metallic badge.",
     None, "video_police_front", "video_police_side"),
    ("Fire", "FYR", "emergency", "beginner", "Essential", "two_handed", "motion",
     "Both open claw hands wiggling fingers as they dance upward like flames.",
     ["Hold both open hands in front of waist, palms facing in.", "Flutter all fingers rapidly as both hands rise upward like flames.", "Alarmed expression."],
     "Moving downward.", "Flames leaping and licking upward into the sky.",
     None, "video_fire_front", "video_fire_side"),
    ("Hurt", "HURT", "emergency", "beginner", "Essential", "two_handed", "motion",
     "Both index fingers jabbing toward each other with twisting wrists.",
     ["Point index fingers at each other.", "Thrust inward with a twist twice.", "Direct at injured spot."],
     "No facial expression.", "Sharp pang of pain.",
     None, "video_hurt_front", "video_hurt_side"),
    ("Danger", "DAYN-jer", "emergency", "intermediate", "Common", "two_handed", "motion",
     "Dominant thumbs-up brushing upward across non-dominant thumbs-up twice.",
     ["Both hands in 'A' fists.", "Dominant thumb brushes upward across non-dominant knuckle twice.", "Warning eyes."],
     "Brushing downward.", "Rising risk level.",
     None, "video_danger_front", "video_danger_side"),
    ("Medicine", "MED-i-sin", "emergency", "intermediate", "Common", "two_handed", "motion",
     "Dominant middle finger pivoting back and forth in non-dominant palm.",
     ["Open non-dominant palm facing up.", "Press bent middle finger into palm and twist back and forth.", "Neutral."],
     "Tapping with index.", "Crushing pills in a mortar.",
     None, "video_medicine_front", "video_medicine_side")
]

def build_catalog_json():
    signs = []
    lessons = []
    units = []

    # 1. Build Alphabet Signs (A-Z)
    alpha_sign_ids = []
    for letter, pron, recog, desc, steps, mist, mnem in ALPHABET_DATA:
        s_id = f"sign-letter-{letter.lower()}"
        alpha_sign_ids.append(s_id)
        signs.append({
            "id": s_id,
            "name": letter,
            "pronunciationHint": pron,
            "category": "alphabet",
            "level": "beginner",
            "frequencyTag": "Fingerspelling",
            "handedness": "dominant",
            "recognition": recog,
            "description": desc,
            "howToSteps": steps,
            "commonMistake": mist,
            "mnemonicTip": mnem,
            "imageName": f"sign_letter_{letter.lower()}",
            "frontVideoName": f"video_letter_{letter.lower()}_front",
            "sideVideoName": f"video_letter_{letter.lower()}_side"
        })

    # 5 Alphabet Lessons (A-E, F-J, K-O, P-T, U-Z)
    alpha_splits = [
        ("lesson-alphabet-1", "Lesson 1: A – E", "Foundational hand shapes and vowels.", alpha_sign_ids[0:5], "Keep your wrist relaxed and thumb positioning precise."),
        ("lesson-alphabet-2", "Lesson 2: F – J", "First dynamic sign and open handshapes.", alpha_sign_ids[5:10], "Pay close attention to J's scooping motion!"),
        ("lesson-alphabet-3", "Lesson 3: K – O", "Finger crossovers and distinct thumb locks.", alpha_sign_ids[10:15], "Notice the subtle difference between M and N."),
        ("lesson-alphabet-4", "Lesson 4: P – T", "Inverted shapes and tricky letter crosses.", alpha_sign_ids[15:20], "P is simply K pointing down to the ground."),
        ("lesson-alphabet-5", "Lesson 5: U – Z", "Final letters and dynamic letter Z.", alpha_sign_ids[20:26], "U has united fingers; V has victory spread fingers.")
    ]

    alpha_lesson_ids = []
    for order, (l_id, title, sub, s_ids, tip) in enumerate(alpha_splits, start=1):
        alpha_lesson_ids.append(l_id)
        lessons.append({
            "id": l_id,
            "unitId": "unit-alphabet",
            "title": title,
            "subtitle": sub,
            "category": "alphabet",
            "signIds": s_ids,
            "order": order,
            "proTip": tip
        })

    units.append({
        "id": "unit-alphabet",
        "title": "Manual Alphabet",
        "description": "Master all 26 letters of American Sign Language fingerspelling.",
        "lessonIds": alpha_lesson_ids,
        "order": 1
    })

    # 2. Build Numbers (1-10)
    num_sign_ids = []
    for num, pron, recog, desc, steps, mist, mnem in NUMBERS_DATA:
        s_id = f"sign-number-{num}"
        num_sign_ids.append(s_id)
        signs.append({
            "id": s_id,
            "name": num,
            "pronunciationHint": pron,
            "category": "numbers",
            "level": "beginner",
            "frequencyTag": "Counting",
            "handedness": "dominant",
            "recognition": recog,
            "description": desc,
            "howToSteps": steps,
            "commonMistake": mist,
            "mnemonicTip": mnem,
            "imageName": f"sign_number_{num}",
            "frontVideoName": f"video_number_{num}_front",
            "sideVideoName": f"video_number_{num}_side"
        })

    lessons.append({
        "id": "lesson-numbers-1",
        "unitId": "unit-numbers",
        "title": "Numbers 1 – 10",
        "subtitle": "Counting and cardinal numbers in ASL.",
        "category": "numbers",
        "signIds": num_sign_ids,
        "order": 6,
        "proTip": "Remember that in ASL 1 through 5, your palm faces inward toward yourself!"
    })

    units.append({
        "id": "unit-numbers",
        "title": "Numbers & Counting",
        "description": "Learn cardinal counting from 1 through 10.",
        "lessonIds": ["lesson-numbers-1"],
        "order": 2
    })

    # 3. Build Vocabulary Words grouped into category lessons
    cat_signs_map = {}
    for word_tuple in VOCABULARY_DATA:
        name, pron, cat, lvl, freq, hands, recog, desc, steps, mist, mnem, intro_vid, front_vid, side_vid = word_tuple
        slug = name.lower().replace(" ", "").replace("'", "")
        s_id = f"sign-word-{slug}"

        if cat not in cat_signs_map:
            cat_signs_map[cat] = []
        cat_signs_map[cat].append(s_id)

        signs.append({
            "id": s_id,
            "name": name,
            "pronunciationHint": pron,
            "category": cat,
            "level": lvl,
            "frequencyTag": freq,
            "handedness": hands,
            "recognition": recog,
            "description": desc,
            "howToSteps": steps,
            "commonMistake": mist,
            "mnemonicTip": mnem,
            "imageName": f"sign_{slug}",
            "frontVideoName": front_vid,
            "sideVideoName": side_vid
        })

    # Vocabulary lessons: one lesson per category
    vocab_lesson_ids = []
    lesson_order = 7
    for cat_dict in CATEGORIES[2:]:  # skip alphabet and numbers
        cat_id = cat_dict["id"]
        cat_name = cat_dict["name"]
        s_ids = cat_signs_map.get(cat_id, [])
        l_id = f"lesson-{cat_id}"
        vocab_lesson_ids.append(l_id)

        lessons.append({
            "id": l_id,
            "unitId": "unit-words-phrases",
            "title": f"{cat_name} Essentials",
            "subtitle": f"Core {cat_name.lower()} signs for real-world interactions.",
            "category": cat_id,
            "signIds": s_ids,
            "order": lesson_order,
            "proTip": f"Practise {cat_name} signs with natural facial expressions."
        })
        lesson_order += 1

    units.append({
        "id": "unit-words-phrases",
        "title": "Words & Everyday Phrases",
        "description": "High-frequency practical signs across everyday topics.",
        "lessonIds": vocab_lesson_ids,
        "order": 3
    })

    return {
        "categories": CATEGORIES,
        "units": units,
        "lessons": lessons,
        "signs": signs
    }

def main():
    catalog = build_catalog_json()
    out_path = Path("/Users/mileeshafernando/IOS/SignSpeak/SignSpeak/Resources/Data/signs.json")
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(catalog, f, indent=2, ensure_ascii=False)

    print(f"[✓] Generated signs.json successfully at: {out_path}")
    print(f"    - Categories: {len(catalog['categories'])}")
    print(f"    - Units:      {len(catalog['units'])}")
    print(f"    - Lessons:    {len(catalog['lessons'])}")
    print(f"    - Signs:      {len(catalog['signs'])}")

if __name__ == "__main__":
    main()
