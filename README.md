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

### Standalone food recognition prototype

The separate [Loop+ meal-review prototype](Prototypes/AIFoodRecognition/README.md) has its own camera/review app, an offline mock mode and opt-in OpenAI analysis through an owner-configured backend. Apple accepted Loop+ **0.3.0 (3)** with a prefilled server address and one-time saved login; authorization renews automatically. Its backend was published with a verified health endpoint on 2026-10-12. See [connection steps and API billing](Prototypes/AIFoodRecognition/Backend/SETUP.md) to try a consented photo; Apple processing, the device update, live provider access and recognition still require owner checks. Reviews stay disconnected from Loop therapy. See the [repository inspection and integration plan](docs/ai-food-recognition.md) for version findings, remaining accuracy validation and future Loop-fork requirements.
