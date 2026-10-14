# LoopWorkspace

The Loop app can be built using GitHub in a browser on any computer or using a Mac with Xcode.

* Non-developers may prefer the GitHub method
* Developers or Loopers who want full build control may prefer the Mac/Xcode method

## GitHub Build Instructions

The GitHub Build Instructions are at this [link](fastlane/testflight.md) and further expanded in [LoopDocs: Browser Build](https://loopkit.github.io/loopdocs/gh-actions/gh-overview/).

## Mac/Xcode Build Instructions

The rest of this README contains information needed for Mac/Xcode build. Additonal instructions are found in [LoopDocs: Mac/Xcode Build](https://loopkit.github.io/loopdocs/build/overview/).

### Clone

This repository uses git submodules to pull in the various workspace dependencies.

To clone this repo:

```
git clone --branch=<branch> --recurse-submodules https://github.com/LoopKit/LoopWorkspace
```

Replace `<branch>` with the initial LoopWorkspace repository branch you wish to checkout.

### Open

Change to the cloned directory and open the workspace in Xcode:

```
cd LoopWorkspace
xed .
```

### Input your development team

You should be able to build to a simulator without changing anything. But if you wish to build to a real device, you'll need a developer account, and you'll need to tell Xcode about your team id, which you can find at https://developer.apple.com/.

Select the LoopConfigOverride file in Xcode's project navigator, uncomment the `LOOP_DEVELOPMENT_TEAM`, and replace the existing team id with your own id.

### Build

Select the "LoopWorkspace" scheme (not the "Loop" scheme) and Build, Run, or Test.

### Meal photo review

The shared [meal-review UI](Prototypes/AIFoodRecognition/README.md) puts editable carb grams and absorption minutes above the explanations. Compact rows keep each numeric label, value and unit on one line, with less padding and smaller section gaps. The photo service allows 1,000 photos per UTC day and 60 per minute. Personal signed builds preconfigure the server/tester login and renew sessions automatically. The standalone Loop+ app and the [pinned Loop 3.14.9 integration](Prototypes/AIFoodRecognition/Integration/README.md) use the same screen. The integration adds **Photograph meal** to Loop's carb-entry screen; accepting the camera capture starts analysis automatically, without a separate upload confirmation. **Use in Loop** copies reviewed values into the existing editable fields before the normal Continue flow.

In native Loop, textual food descriptions use a full-width multiline field below the Food Type label. The bolus summary shows the full wrapped description below the carb amount and time/absorption. The complete description remains editable and is preserved.

Apple accepted **Loop+ 0.4.0 (4)** and **integrated Loop 3.14.9 (24)** through the checked TestFlight workflows. The native update passed all 46 Swift tests, configuration checks, full simulator compilation, signed device/Watch archive and upload in [run 38497005480](https://github.com/jhardorp/LoopWorkspace/actions/runs/38497005480). The phone update follows Apple processing.
