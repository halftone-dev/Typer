# Typer

An open-source voice dictation tool for macOS that respects your privacy.

## Why Typer?

Voice dictation will (if not has) become an indispensable tool for many,
offering significant productivity gains and accessibility benefits. However,
existing solutions come with a serious privacy concern: they require extensive
accessibility permissions that allow them to monitor *all* your activities,
essentially giving them the ability to spy on everything you do on your Mac,
24/7.

### The Privacy Problem

There are two layers of privacy problem for a tool like Typer.

1. The voice and text you dictate maybe collected. But you can always choose to
   not use dictation if the subject is too sensitive. Running this
   speech-to-text model locally could make it bulletproof. However, that is a
   trade-off with the latency and memory footprint.

1. A much bigger problem. For such tool to do a better job, it needs the context
   through the accessibility API. And this API is much more powerful than most
   people would think.

When you grant accessibility permissions to a dictation app, you're giving it:

- Access to read all window content (even from applications running in
  background)
- Ability to monitor all keyboard and mouse inputs
- Permission to control your computer
- Continuous background monitoring capabilities

While current commercial solutions may be trustworthy, circumstances can change:

- Companies can be acquired
- Privacy policies can be updated
- Software can be compromised
- Business models can shift

### Typer's Solution

Typer is built with privacy as its cornerstone:

- 🔍 **Open Source**: Every line of code is visible and auditable
- 🔒 **Transparency**: You can see exactly how accessibility permissions are used
- 💪 **Control**: You maintain control over your data and privacy

## Features

- Voice-to-text transcription using either OpenAI's API or Typer's own backend API
- Universal text insertion across macOS applications
- Hotkey toggle for easy recording
- Command mode support for post-processiong with preview
- Local Voice-to-text model support

## Requirements

- macOS 13.0 or later
- OpenAPI key or Typer API
- Microphone permissions
- Accessibility permissions

## BUILD

### Prerequisites

- Xcode 14.0 or later
- Git

### Steps to Build

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/Typer.git
   cd Typer
   ```

1. Open the project in Xcode:

   ```bash
   open Typer.xcodeproj
   ```

   Alternatively, you can double-click the `Typer.xcodeproj` file in Finder.

1. Select your development team in Xcode:

   - Click on the Typer project in the Project Navigator
   - Select the Typer target
   - Go to the "Signing & Capabilities" tab
   - Select your team from the dropdown

1. Build the project:

   - Select the Typer scheme
   - Choose your target device (Your Mac)
   - Press Cmd+B or select Product > Build from the menu

1. Run the application:

   - Press Cmd+R or select Product > Run from the menu

### Troubleshooting

If you encounter any issues:

- Make sure all required permissions are granted
- Check the console for any error messages
- Ensure your Xcode version is compatible

## Usage

1. Launch Typer
1. Grant necessary permissions
1. Hold the Hotkey (defulat Function (fn) key to record
1. Release to transcribe and insert text

## License

[License information to be added]
