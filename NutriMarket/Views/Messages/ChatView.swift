import SwiftUI
import FirebaseAuth

struct ChatView: View {
    var conversation: Conversation?
    var newChatUserID: String?
    var newChatUserName: String = ""
    var newChatUserAvatar: String = ""
    let messagesManager: MessagesManager

    @EnvironmentObject var authManager: AuthManager
    @State private var messageText = ""
    @State private var isSending = false
    @State private var isOtherOnline = false
    @State private var refreshID = UUID()
    @FocusState private var isFocused: Bool

    var convID: String {
        if let conv = conversation { return conv.id }
        guard let uid = Auth.auth().currentUser?.uid,
              let toUID = newChatUserID else { return "" }
        return [uid, toUID].sorted().joined(separator: "_")
    }

    var otherUserName: String { conversation?.otherUserName ?? newChatUserName }
    var otherUserAvatar: String { conversation?.otherUserAvatar ?? newChatUserAvatar }
    var otherUserID: String { conversation?.otherUserID ?? newChatUserID ?? "" }

    var body: some View {
        VStack(spacing: 0) {
            messagesList
            Divider()
            inputBar
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { chatToolbar }
        .onAppear {
            messagesManager.startListeningMessages(conversationID: convID)
            messagesManager.observePresence(userID: otherUserID)
            messagesManager.setOnline()
            Task { await messagesManager.markMessagesAsRead(conversationID: convID) }
        }
        .onDisappear {
            messagesManager.stopObservingPresence()
        }
        .onReceive(messagesManager.$messages) { _ in
            refreshID = UUID()
            // Marca como lido quando novas mensagens chegam
            Task { await messagesManager.markMessagesAsRead(conversationID: convID) }
        }
        .onReceive(messagesManager.$onlineUsers) { onlineSet in
            isOtherOnline = onlineSet.contains(otherUserID)
        }
    }

    var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(messagesManager.messages.enumerated()), id: \.element.id) { index, msg in
                        messageBubble(msg: msg, index: index)
                            .id(msg.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding()
                .id(refreshID)
            }
            .onChange(of: messagesManager.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    func messageBubble(msg: Message, index: Int) -> some View {
        let isMe = msg.senderID == authManager.currentUser?.uid
        let isLast = index == messagesManager.messages.count - 1
        return MessageBubble(
            message: msg,
            isMe: isMe,
            isLast: isLast,
            otherUserName: otherUserName
        )
    }

    var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Mensagem...", text: $messageText, axis: .vertical)
                .padding(10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($isFocused)
                .lineLimit(1...5)

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(
                        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.secondary : Color.blue
                    )
            }
            .disabled(
                messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending
            )
        }
        .padding(.horizontal).padding(.vertical, 10)
        .background(Color(.systemBackground))
    }

    @ToolbarContentBuilder
    var chatToolbar: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text(otherUserName).font(.headline)
                HStack(spacing: 4) {
                    Circle()
                        .fill(isOtherOnline ? Color.green : Color(.systemGray4))
                        .frame(width: 8, height: 8)
                    Text(isOtherOnline ? "online" : "offline")
                        .font(.caption2)
                        .foregroundStyle(isOtherOnline ? .green : .secondary)
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            AvatarView(url: otherUserAvatar, size: 32)
        }
    }

    func send() async {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        messageText = ""
        await messagesManager.sendMessage(
            toUserID: otherUserID,
            toUserName: otherUserName,
            toUserAvatar: otherUserAvatar,
            text: text
        )
        isSending = false
    }
}

struct MessageBubble: View {
    let message: Message
    let isMe: Bool
    let isLast: Bool
    let otherUserName: String

    var body: some View {
        HStack(alignment: .bottom) {
            if isMe { Spacer(minLength: 60) }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(isMe ? Color.blue : Color(.systemGray5))
                    .foregroundStyle(isMe ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                HStack(spacing: 4) {
                    Text(message.createdAt.timeAgoDisplay())
                        .font(.caption2).foregroundStyle(.secondary)
                    if isMe && isLast {
                        Text(message.read ? "visto" : "enviado")
                            .font(.caption2)
                            .foregroundStyle(message.read ? Color.blue : Color.secondary)
                    }
                }
            }

            if !isMe { Spacer(minLength: 60) }
        }
    }
}
