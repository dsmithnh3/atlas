//
//  FirstRunView.swift
//  Atlas
//
//  Onboarding experience for first-time users
//

import SwiftUI

struct FirstRunView: View {
    @Binding var isPresented: Bool
    var onOpenFile: () -> Void

    @State private var animationPhase: Int = 0

    var body: some View {
        VStack(spacing: 32) {
            // App icon / logo area
            VStack(spacing: 12) {
                Image(systemName: "map.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)
                    .symbolEffect(.pulse, options: .repeating, value: animationPhase)

                Text("Welcome to Atlas")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("A Spatial Reading Companion")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            // Feature highlights
            VStack(alignment: .leading, spacing: 16) {
                featureRow(
                    icon: "brain",
                    title: "AI-Powered Knowledge Maps",
                    description: "Concepts are extracted and organized as you read"
                )
                featureRow(
                    icon: "arrow.left.arrow.right",
                    title: "Bidirectional Navigation",
                    description: "Click a concept to jump to its source, scroll to see active concepts"
                )
                featureRow(
                    icon: "doc.on.doc",
                    title: "Cross-Document Insights",
                    description: "Add multiple PDFs to a project and discover connections"
                )
                featureRow(
                    icon: "keyboard",
                    title: "Keyboard-First",
                    description: "Cmd+1/2/3 to switch views, Cmd+K to search everything"
                )
            }
            .frame(maxWidth: 400)

            // Actions
            VStack(spacing: 12) {
                Button(action: {
                    isPresented = false
                    onOpenFile()
                }) {
                    Label("Open a PDF to Get Started", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Skip") {
                    isPresented = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            // Setup reminder
            Text("Configure your AI backend in Settings > AI to enable concept extraction")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(48)
        .frame(maxWidth: 520)
        .onAppear {
            animationPhase += 1
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
