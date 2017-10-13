//
//  ClusterWS.swift
//  ClusterWS-Client-Swift
//
//  Created by Roman Baitaliuk on 3/10/17.
//

import Foundation

open class ClusterWS {
    
    //MARK: Properties
    
    public var delegate: ClusterWSDelegate?
    
    open let mEmitter: Emitter!
    open var mChannels: [Channel]!
    open var mLost: Int = 0
    open var timer: Timer?
    
    private let mUrl: String!
    private let mPort: Int!
    
    private var mReconnectionHandler: Reconnection!
    private var mWebSocket: WebSocket!
    
    //MARK: Initialization
    
    public init(url: String, port: Int) {
        self.mUrl = url
        self.mPort = port
        self.mChannels = []
        self.mEmitter = Emitter()
        self.mReconnectionHandler = Reconnection(autoReconnect: nil, reconnectionIntervalMin: nil, reconnectionIntervalMax: nil, reconnectionAttempts: nil, socket: self)
    }
    
    //MARK: Public methods
    
    public func connect() {
        self.mWebSocket = WebSocket(url: URL(string: "ws://\(self.mUrl!):\(self.mPort!)/")!)
        self.mWebSocket.event.open = {
            print("opened")
            self.mReconnectionHandler.onConnected()
            self.delegate?.onConnect()
        }
        self.mWebSocket.event.close = { code, reason, clean in
            print("close with code: \(code), reason: \(reason)")
            self.mLost = 0
            self.timer?.invalidate()
            self.delegate?.onDisconnect(code: code, reason: reason)
            if self.mReconnectionHandler.mInReconnectionState {
                return
            }
            if self.mReconnectionHandler.mAutoReconnect && code != 1000 {
                self.mReconnectionHandler.reconnect()
            }
        }
        self.mWebSocket.event.error = { error in
            print("error \(error)")
            self.delegate?.onError(error: error)
        }
        self.mWebSocket.event.message = { message in
            if let text = message as? String {
                if text == "#0" {
                    self.mLost = 0
                    self.send(event: "#1", data: nil, type: .ping)
                } else {
                    Message.messageDecode(socket: self, message: text)
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + self.mReconnectionHandler.mReconnectionIntervalMin) {
            print(self.mWebSocket.readyState)
            if self.mWebSocket.readyState == .closed {
                self.mReconnectionHandler.reconnect()
            }
        }
    }
    
    public func on(event: String, completion: @escaping CompletionHandler) {
        self.mEmitter.on(event: event, completion: completion)
    }
    
    public func subscribe(channelName: String) -> Channel {
        var channel: Channel?
        _ = self.mChannels.filter { $0.mChannelName == channelName }.map { channel == $0 }
        if channel == nil {
            channel = Channel(channelName: channelName, socket: self)
            self.mChannels.append(channel!)
        }
        return channel!
    }
    
    public func getChannels() -> [Channel] {
        return self.mChannels
    }
    
    public func getChannel(byName name: String) -> Channel? {
        return self.mChannels.filter { $0.mChannelName == name }.first
    }
    
    public func disconnect(closeCode: Int? = nil, reason: String? = nil) {
        self.mWebSocket.close(closeCode == nil ? 1000 : closeCode!, reason: reason == nil ? "" : reason!)
    }
    
    public func setReconnection(autoReconnect: Bool, reconnectionIntervalMin: Double, reconnectionIntervalMax: Double, reconnectionAttempts: Int) {
        self.mReconnectionHandler = Reconnection(autoReconnect: autoReconnect, reconnectionIntervalMin: reconnectionIntervalMin, reconnectionIntervalMax: reconnectionIntervalMax, reconnectionAttempts: reconnectionAttempts, socket: self)
    }
    
    public func getState() -> WebSocketReadyState {
        return self.mWebSocket.readyState
    }
    
    public func send(event: String, data: Any? = nil) {
        self.send(event: event, data: data, type: .emit)
    }
    
    //MARK: Open methods within the ClusterWS module
    
    open func send(event: String, data: Any? = nil, type: MessageType? = .emit) {
        self.mWebSocket.send(Message.messageEncode(event: event, data: data, type: type!))
    }
}
