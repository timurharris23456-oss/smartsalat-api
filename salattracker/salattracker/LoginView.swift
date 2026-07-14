//
//  LoginView.swift
//  salattracker
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var username = ""
    @State private var password = ""
    @State private var isRegistering = false

    private var canSubmit: Bool { username.count >= 3 && password.count >= 6 }

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

    private func submit() {
        Task {
            if isRegistering {
                await auth.register(username: username, password: password)
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
