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
        .background(
            LinearGradient(
                colors: [Color.indigo.opacity(0.10), Color(uiColor: .systemBackground), Color.blue.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
}

private struct OnboardingHero: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient(colors: [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "square.3.layers.3d.top.filled")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 94, height: 94)
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
            Button(action: completion) {
                Label("Sign In with Apple", systemImage: "apple.logo")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 500)
    }
}
