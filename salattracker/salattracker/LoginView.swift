//
//  LoginView.swift
//  salattracker
//

import SwiftUI
import PhotosUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarData: Data?

    private var canSubmit: Bool { username.count >= 3 && password.count >= 6 }

    private var avatarInitials: String {
        let letters = username.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                VStack(spacing: 10) {
                    Text("🕌").font(.system(size: 60))
                    Text("SmartSalat")
                        .font(.largeTitle.bold())
                        .foregroundStyle(Theme.text)
                    Text(isRegistering ? "Create your account" : "Welcome back")
                        .font(.subheadline)
                        .foregroundStyle(Theme.subtle)
                }

                if isRegistering {
                    avatarPicker
                }

                VStack(spacing: 12) {
                    field(icon: "person.fill", placeholder: "Username", text: $username)
                    field(icon: "lock.fill", placeholder: "Password", text: $password, secure: true)
                }

                if let error = auth.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: submit) {
                    HStack(spacing: 8) {
                        if auth.isWorking { ProgressView().tint(.white) }
                        Text(isRegistering ? "Sign Up" : "Log In")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canSubmit ? AnyShapeStyle(Theme.primary) : AnyShapeStyle(Theme.subtle),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(!canSubmit || auth.isWorking)

                Button {
                    isRegistering.toggle()
                    auth.errorMessage = nil
                } label: {
                    Text(isRegistering ? "Already have an account? Log in"
                                       : "New here? Create an account")
                        .font(.subheadline)
                        .foregroundStyle(Theme.primary)
                }

                Spacer()
                Spacer()
            }
            .padding(28)
        }
    }

    private var avatarPicker: some View {
        VStack(spacing: 6) {
            PhotosPicker(selection: $avatarItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(initials: avatarInitials, imageData: avatarData, size: 92)
                        .overlay(Circle().strokeBorder(Theme.primary.opacity(0.25), lineWidth: 1))
                    Image(systemName: "camera.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Theme.primary, in: Circle())
                        .overlay(Circle().strokeBorder(Theme.background, lineWidth: 2))
                }
            }
            Text("Add a profile photo (optional)")
                .font(.caption)
                .foregroundStyle(Theme.subtle)
        }
        .onChange(of: avatarItem) { _, item in
            Task {
                if let item, let raw = try? await item.loadTransferable(type: Data.self) {
                    avatarData = ProfileImage.jpeg(from: raw)
                }
            }
        }
    }

    private func submit() {
        Task {
            if isRegistering {
                await auth.register(username: username, password: password, avatar: avatarData)
            } else {
                await auth.signIn(username: username, password: password)
            }
        }
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, secure: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.subtle)
                .frame(width: 22)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .textInputAutocapitalization(.never)
                }
            }
            .autocorrectionDisabled()
        }
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
