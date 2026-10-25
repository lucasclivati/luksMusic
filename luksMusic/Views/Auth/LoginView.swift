// LoginView.swift
// luksMusic
//
// Onboarding and authentication screen allowing login with Google, Apple, or Guest mode.

import SwiftUI

struct LoginView: View {
    @State private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(
                colors: [Color(white: 0.08), Color(white: 0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // App Logo & Title
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.accentColor, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 90, height: 90)
                            .shadow(color: .accentColor.opacity(0.4), radius: 16)
                        
                        Image(systemName: "pianokeys")
                            .font(.system(size: 44))
                            .foregroundColor(.white)
                    }
                    
                    Text("luksMusic")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Smart Piano Studio & Sheet Music Scanner")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                // Features Highlights
                VStack(spacing: 14) {
                    featureRow(icon: "icloud.fill", color: .blue, title: "Firebase Cloud Sync", subtitle: "Your scores & recordings saved online securely")
                    featureRow(icon: "camera.viewfinder", color: .purple, title: "Music OCR Scanner", subtitle: "Convert printed piano sheets into digital notation")
                    featureRow(icon: "waveform", color: .green, title: "Interactive Piano Practice", subtitle: "Guided mode, falling notes & MIDI keyboard input")
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    // Google Sign-In Button
                    Button {
                        Task {
                            await authService.signInWithGoogle()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text("Sign in with Google")
                                .font(.headline)
                                .foregroundColor(.primary)
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
                    
                    // Apple Sign-In Button
                    Button {
                        Task {
                            await authService.signInWithApple()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "apple.logo")
                                .font(.headline)
                            Text("Sign in with Apple")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(12)
                    }
                    
                    // Continue as Guest
                    Button {
                        authService.continueAsGuest()
                    } label: {
                        Text("Continue as Guest")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
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
