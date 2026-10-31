import CoreText
import Foundation
import os

/// Registers the bundled typefaces with the process, once, before the first text renders.
/// Fonts live in this package rather than the app's Info.plist so previews and tests get them too.
enum FontRegistrar {
    static let sansFamily = "Instrument Sans"
    static let serifFamily = "Newsreader"

    private static let files = ["InstrumentSans", "Newsreader", "Newsreader-Italic"]
    private static let logger = Logger(subsystem: "com.shubhamtyagi.pocketoven", category: "Fonts")

    /// Which families resolved. Evaluating this the first time performs the registration.
    static let availability: Availability = {
        for name in files {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf") else {
                logger.error("Missing bundled font \(name, privacy: .public)")
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already registered (e.g. a second test bundle in the same process) is fine.
                logger.debug("Font \(name, privacy: .public) not registered: \(String(describing: error?.takeRetainedValue()), privacy: .public)")
            }
        }
        return Availability(sans: isInstalled(sansFamily), serif: isInstalled(serifFamily))
    }()

    struct Availability: Equatable {
        let sans: Bool
        let serif: Bool
    }

    private static func isInstalled(_ family: String) -> Bool {
        let descriptor = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: family] as CFDictionary)
        let matches = CTFontDescriptorCreateMatchingFontDescriptors(descriptor, nil) as? [CTFontDescriptor]
        return !(matches ?? []).isEmpty
    }
}
