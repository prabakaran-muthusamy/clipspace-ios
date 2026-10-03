//
//  OnboardingView.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import SwiftUI

struct OnboardingView: View {
    let completion: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 36)
            OnboardingHero()
            Spacer(minLength: 30)
            OnboardingFeatures()
            Spacer(minLength: 30)
            OnboardingActions(completion: completion)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 18)
        .background(LinearGradient(colors: [Color.indigo.opacity(0.10),
                                            Color(uiColor: .systemBackground),
                                            Color.blue.opacity(0.05)],
                                   startPoint: .topLeading,
                                   endPoint: .bottomTrailing)
            .ignoresSafeArea())
    }
}

private struct OnboardingHero: View {
    var body: some View {
        VStack(spacing: 14) {
            Image("AppIcon")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .blue.opacity(0.25), radius: 16, y: 8)
            
            Text("ClipSpace")
                .font(.largeTitle.bold())
            
            Text("Your clipboard everywhere.")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct OnboardingFeatures: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingFeature(symbol: "laptopcomputer.and.iphone", title: "Access across all your devices")
            OnboardingFeature(symbol: "sparkles", title: "Smart suggestions")
            OnboardingFeature(symbol: "lock.shield", title: "Secure and private")
            OnboardingFeature(symbol: "waveform", title: "Works with Shortcuts, Siri and more")
        }
        .frame(maxWidth: 440)
    }
}

private struct OnboardingFeature: View {
    let symbol: String
    let title: LocalizedStringKey
    
    var body: some View {
        Label {
            Text(title).font(.body.weight(.medium))
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(ClipSpaceStyle.blue)
                .frame(width: 30)
        }
    }
}

private struct OnboardingActions: View {
    let completion: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            Button("Get Started", action: completion)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(ClipSpaceStyle.blue, in: Capsule())
        }
        .frame(maxWidth: 500)
    }
}
