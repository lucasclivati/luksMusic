// LoginView.swift
// luksMusic
//
// Modern authentication screen allowing login with Google, Firebase Email/Password, Apple, or Guest mode.

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @State private var authService = AuthService.shared
    @State private var emailInput: String = ""
    @State private var passwordInput: String = ""
    @State private var showEmailForm: Bool = false
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [Color(white: 0.08), Color(white: 0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    Spacer(minLength: 20)
                    
                    // App Logo & Title
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.accentColor, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 84, height: 84)
                                .shadow(color: .accentColor.opacity(0.4), radius: 16)
                            
                            Image(systemName: "pianokeys")
                                .font(.system(size: 40))
                                .foregroundColor(.white)
                        }
                        
                        Text("luksMusic")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Partituras interativas e prática de piano")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Features Highlights
                    VStack(spacing: 12) {
                        featureRow(icon: "icloud.fill", color: .blue, title: "Biblioteca na nuvem", subtitle: "Entre com sua conta para guardar suas partituras")
                        featureRow(icon: "waveform", color: .green, title: "Piano Interativo e Prática", subtitle: "Teclado interativo, metrônomo e partitura conectada")
                    }
                    .padding(.horizontal, 24)
                    
                    // Error Notice if any
                    if let err = authService.authError {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Action Buttons
                    VStack(spacing: 14) {
                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            authService.prepareAppleRequest(request)
                        } onCompletion: { result in
                            Task {
                                await authService.signInWithApple(result)
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 50)
                        .cornerRadius(12)
                        .disabled(authService.isAuthenticating)

                        // Google Sign-In Button
                        Button {
                            Task {
                                await authService.signInWithGoogle()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                if authService.isAuthenticating {
                                    ProgressView()
                                        .tint(.primary)
                                } else {
                                    Image(systemName: "globe")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    Text("Entrar com Google")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                        .disabled(authService.isAuthenticating)
                        
                        // Email / Password Toggle Button & Form
                        VStack(spacing: 10) {
                            if showEmailForm {
                                VStack(spacing: 10) {
                                    TextField("E-mail", text: $emailInput)
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .padding(12)
                                        .background(Color(.tertiarySystemBackground))
                                        .cornerRadius(8)
                                    
                                    SecureField("Senha", text: $passwordInput)
                                        .textContentType(.password)
                                        .padding(12)
                                        .background(Color(.tertiarySystemBackground))
                                        .cornerRadius(8)
                                    
                                    Button {
                                        Task {
                                            await authService.signInWithEmail(email: emailInput, password: passwordInput)
                                        }
                                    } label: {
                                        Text("Entrar / Criar Conta")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(Color.blue)
                                            .cornerRadius(8)
                                    }
                                    .disabled(passwordInput.count < 6 || authService.isAuthenticating)
                                }
                                .padding(14)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            } else {
                                Button {
                                    withAnimation {
                                        showEmailForm = true
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "envelope.fill")
                                            .font(.subheadline)
                                        Text("Entrar com E-mail")
                                            .font(.subheadline)
                                    }
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Continue as Guest
                        Button {
                            authService.continueAsGuest()
                        } label: {
                            Text("Continuar como Convidado (Offline)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 6)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
    }
    
    @ViewBuilder
    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}
