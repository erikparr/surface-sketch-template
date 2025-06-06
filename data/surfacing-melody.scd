// @surfacing-melody.scd
// Tuba Melody Dictionary for the 'surfacing' composition

(
// Create the melody dictionary
~melodyDict = Dictionary.new;

// Basic melodies
~melodyDict.put(\set1, (
    name: "Tuba Melody I",
    patterns: [
        [94, 89, 84, 78, 94],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // Normal velocity for last note
    )
));

~melodyDict.put(\set1b, (
    name: "Tuba Melody I",
    patterns: [
        [94, 89, 84, 78, 94, 89, 84, 78, 94],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));

~melodyDict.put(\set2, (
    name: "Tuba Melody II",
    patterns: [
        [89, 84, 81, 77, 89],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));

~melodyDict.put(\set3, (
    name: "Tuba Melody III",
    patterns: [
        [90, 85, 82, 75, 90],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));

~melodyDict.put(\set4, (
    name: "Tuba Melody IV",
    patterns: [
        [90, 85, 78, 73, 90],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));

~melodyDict.put(\set5, (
    name: "Tuba Melody V",
    patterns: [
        [89, 85, 82, 75, 89],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));

~melodyDict.put(\set6, (
    name: "Tuba Melody VI",
    patterns: [
        [87, 82, 78, 73, 87],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));

~melodyDict.put(\set7, (
    name: "Tuba Melody VII",
    patterns: [
        [89, 82, 78, 73, 89],
    ],
    velocityMultipliers: (
        first: 1.5,  // 150% velocity for first note
        last: 0.5    // 50% velocity for last note
    )
));

~melodyDict.put(\set8, (
    name: "Tuba Melody VIII",
    patterns: [
        [85, 82, 78, 75],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    )
));

~melodyDict.put(\set9, (
    name: "Tuba Melody IX",
    patterns: [
        [94, 89, 84, 78, 70],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    )
));

// Variant melodies
~melodyDict.put(\set2a, (
    name: "Tuba Melody IX",
    patterns: [
        [94, 87, 82, 75, 94],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    )
));

~melodyDict.put(\set2b, (
    name: "Tuba Melody IX",
    patterns: [
        [93, 87, 82, 78, 93],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    )
));

~melodyDict.put(\set2c, (
    name: "Tuba Melody IX",
    patterns: [
        [91, 87, 82, 75, 91],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    )
));

~melodyDict.put(\set2d, (
    name: "Tuba Melody IX",
    patterns: [
        [94, 90, 82, 78, 94],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    )
));

~melodyDict.put(\set3a, (
    name: "Tuba Melody IX",
    patterns: [
        [82, 77, 78, 73, 82],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    )
));

// Set 4 melodies with loop counts
~melodyDict.put(\set4a, (
    name: "Tuba Melody IX",
    patterns: [
        [81, 77, 72, 65, 81],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 15
));

~melodyDict.put(\set4b, (
    name: "Tuba Melody IX",
    patterns: [
        [82, 77, 72, 65, 82],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 9
));

~melodyDict.put(\set4c, (
    name: "Tuba Melody IX",
    patterns: [
        [78, 75, 72, 65, 78],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 3
));

~melodyDict.put(\set4d, (
    name: "Tuba Melody IX",
    patterns: [
        [85, 82, 73, 66, 85],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 9
));

~melodyDict.put(\set4e, (
    name: "Tuba Melody IX",
    patterns: [
        [78, 77, 70, 66, 78],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 9
));

~melodyDict.put(\set4f, (
    name: "Tuba Melody IX",
    patterns: [
        [78, 77, 85, 82, 78],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 15
));

// Bridge melodies
~melodyDict.put(\bridge1a, (
    name: "Tuba Melody IX",
    patterns: [
        [82, 77, 70, 82],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 15
));

~melodyDict.put(\bridge1b, (
    name: "Tuba Melody IX",
    patterns: [
        [ 84, 81, 72, 84],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 0.5
    ),
    loopCount: 15
));

~melodyDict.put(\bridge1bA, (
    name: "Tuba Melody IX",
    patterns: [
        [ 81, 77, 72, 84],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 15
));

~melodyDict.put(\bridge1bB, (
    name: "Tuba Melody IX",
    patterns: [
        [ 81, 77, 65, 81],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 15
));

~melodyDict.put(\bridge1c, (
    name: "Tuba Melody IX",
    patterns: [
        [85, 82, 66, 85],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 15
));

~melodyDict.put(\bridge2a, (
    name: "Tuba Melody IX",
    patterns: [
        [ 78, 73, 70, 63, 78],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 0.5
    ),
    loopCount: 15
));

~melodyDict.put(\bridge2b, (
    name: "Tuba Melody IX",
    patterns: [
        [ 66, 61, 0, 0, 66],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 0.5
    ),
    loopCount: 15
));

// Part 2 and 3 melodies
~melodyDict.put(\part2a, (
    name: "Tuba Melody X",
    patterns: [
        [77, 75, 77, 89, 78, 75, 77, 78, 90, 77, 78, 94, 82, 73, 77, 89, 78],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    )
));

~melodyDict.put(\part2b, (
    name: "Tuba Melody XI",
    patterns: [
        [70, 85, 72, 87, 73, 89, 75, 87, 75, 85, 70, 84, 72, 82, 70, 85],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    )
));

~melodyDict.put(\part3x, (
    name: "Tuba Melody X",
    patterns: [
        [70, 85, 72, 87, 73, 89, 75, 87, 75, 85, 70, 84, 72, 82, 70, 85],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    )
));

~melodyDict.put(\part3a, (
    name: "Tuba Melody X",
    patterns: [
        [70, 85, 84, 70],
    ],
    velocityMultipliers: (
        first: 1,
        last: 1
    ),
    loopCount: 5
));

~melodyDict.put(\part3b, (
    name: "Tuba Melody X",
    patterns: [
        [72, 85, 87, 72],
    ],
    velocityMultipliers: (
        first: 1,
        last: 1
    ),
    loopCount: 5
));

~melodyDict.put(\part3c, (
    name: "Tuba Melody X",
    patterns: [
        [73, 89, 87, 73],
    ],
    velocityMultipliers: (
        first: 1,
        last: 1
    ),
    loopCount: 5
));

~melodyDict.put(\part3d, (
    name: "Tuba Melody X",
    patterns: [
        [72, 87, 85, 72],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 5
));

~melodyDict.put(\part3e, (
    name: "Tuba Melody X",
    patterns: [
        [70, 85, 84, 70],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 5
));

~melodyDict.put(\part3f, (
    name: "Tuba Melody X",
    patterns: [
        [72, 87, 82, 72],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 5
));

~melodyDict.put(\part3g, (
    name: "Tuba Melody X",
    patterns: [
        [70, 82, 85, 70],
    ],
    velocityMultipliers: (
        first: 1.5,
        last: 1.0
    ),
    loopCount: 5
));

~melodyDict.put(\part4a, (
    name: "Tuba Melody XII",
    patterns: [
        [ 65, 81, 77, 65],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    ),
    loopCount: 5
));

~melodyDict.put(\part4b, (
    name: "Tuba Melody XII",
    patterns: [
        [ 65, 82, 77, 65],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    ),
    loopCount: 5
));

~melodyDict.put(\part4c, (
    name: "Tuba Melody XII",
    patterns: [
        [ 61, 77, 75, 61],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    ),
    loopCount: 5
));


~melodyDict.put(\part5a, (
    name: "Tuba Melody XIII",
    patterns: [
        [ 72, 84, 81, 72],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    ),
    loopCount: 5
));
~melodyDict.put(\part5b, (
    name: "Tuba Melody XIII",
    patterns: [
        [ 70, 82, 85, 70],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    ),
    loopCount: 5
));
~melodyDict.put(\part5c, (
    name: "Tuba Melody XIII",
    patterns: [
        [ 70, 82, 84, 70],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    ),
    loopCount: 5
));
~melodyDict.put(\part5d, (
    name: "Tuba Melody XIII",
    patterns: [
        [ 69, 81, 77, 69],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    ),
    loopCount: 5
));
~melodyDict.put(\part5e, (
    name: "Tuba Melody XIII",
    patterns: [
        [ 66, 78, 75, 66],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    ),
    loopCount: 5    
));

~melodyDict.put(\part5f, (
    name: "Tuba Melody XIV",
    patterns: [
        [65, 72, 70, 65],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    ),
    loopCount: 5
));

~melodyDict.put(\part5g, (
    name: "Tuba Melody XIV",
    patterns: [
        [65, 72, 70, 65],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    ),
    loopCount: 5
));

~melodyDict.put(\part5h, (
    name: "Tuba Melody XIV",
    patterns: [
        [65, 81, 77, 65],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 1.0
    ),
    loopCount: 5
));



// Loop melodies
~melodyDict.put(\loop1, (
    name: "Tuba Melody XI",
    patterns: [
        [94, 89, 66],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));

~melodyDict.put(\loop1a, (
    name: "Tuba Melody XI",
    patterns: [
        [89, 94, 66],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));

~melodyDict.put(\loop2, (
    name: "Tuba Melody XII",
    patterns: [
        [94, 89, 82],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));

~melodyDict.put(\loop3, (
    name: "Tuba Melody XIII",
    patterns: [
        [94, 89, 78],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));

~melodyDict.put(\loop4, (
    name: "Tuba Melody XIV",
    patterns: [
        [94, 89, 77],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));

~melodyDict.put(\loop5, (
    name: "Tuba Melody XV",
    patterns: [
        [94, 89, 73],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));

~melodyDict.put(\loop6, (
    name: "Tuba Melody XVI",
    patterns: [
        [94, 89, 66],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));

~melodyDict.put(\loop7, (
    name: "Tuba Melody XVII",
    patterns: [
        [94, 89, 70],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));

~melodyDict.put(\loop8, (
    name: "Tuba Melody XVIII",
    patterns: [
        [94, 89, 65],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 8
));

~melodyDict.put(\loop9, (
    name: "Tuba Melody XI",
    patterns: [
        [94, 89, 61],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));

~melodyDict.put(\loop9a, (
    name: "Tuba Melody XI",
    patterns: [
        [89, 94, 61],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));

~melodyDict.put(\loop10, (
    name: "Tuba Melody XI",
    patterns: [
        [94, 89, 65],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));

~melodyDict.put(\loop10a, (
    name: "Tuba Melody XI",
    patterns: [
        [89, 94, 65],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));

~melodyDict.put(\loop11, (
    name: "Tuba Melody XI",
    patterns: [
        [94, 89, 63],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));

~melodyDict.put(\loop11a, (
    name: "Tuba Melody XI",
    patterns: [
        [89, 94, 63],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));

~melodyDict.put(\loop12, (
    name: "Tuba Melody XII",
    patterns: [
        [94, 89, 60],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));

~melodyDict.put(\loop12a, (
    name: "Tuba Melody XII",
    patterns: [
        [89, 94, 60],
    ],
    velocityMultipliers: (
        first: 1.0,
        last: 2.0
    ),
    loopCount: 1
));

// Return the melody dictionary so it's available when loaded
~melodyDict;
) 