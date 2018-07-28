//
//  ChatRoom.swift
//  DogeChat
//
//  Created by Piyush Chhabra on 7/25/18.
//  Copyright © 2018 Luke Parham. All rights reserved.
//

import UIKit

protocol ChatRoomDelegate: class {
    func receivedMessage(message: Message)
}

class ChatRoom: NSObject {
    //1
    var inputStream: InputStream!
    var outputStream: OutputStream!
    
    //2
    var username = ""
    
    //3
    let maxReadLength = 4096
    
    weak var delegate: ChatRoomDelegate?

    
    func setupNetworkCommunication() {
        // 1
        var readStream: Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        
        // 2
        CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault,
                                           "localhost" as CFString,
                                           80,
                                           &readStream,
                                           &writeStream)
        
        inputStream = readStream!.takeRetainedValue()
        outputStream = writeStream!.takeRetainedValue()
        inputStream.delegate = self
        
 
        inputStream.schedule(in: .current, forMode: .commonModes)
        outputStream.schedule(in: .current, forMode: .commonModes)
        inputStream.open()
        outputStream.open()
    }
    
    func joinChat(username: String) {
        //1
        let data = "iam:\(username)".data(using: .ascii)!
        //2
        self.username = username
        
        //3
        _ = data.withUnsafeBytes { outputStream.write($0, maxLength: data.count) }
    }
}

extension ChatRoom: StreamDelegate {
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            readAvailableBytes(stream: aStream as! InputStream)
            print("new message received")
        case Stream.Event.endEncountered:
            stopChatSession()
            print("new message received")
        case Stream.Event.errorOccurred:
            print("error occurred")
        case Stream.Event.hasSpaceAvailable:
            print("has space available")
        default:
            print("some other event...")
            break
        }
    }
 
    
    private func readAvailableBytes(stream: InputStream) {
        //1
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
        
        //2
        while stream.hasBytesAvailable {
            //3
            let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
            
            //4
            if numberOfBytesRead < 0 {
                if let _ = stream.streamError {
                    break
                }
            }
            //Construct the Message object
            if let message = processedMessageString(buffer: buffer, length: numberOfBytesRead) {
                
                delegate?.receivedMessage(message: message)
                //Notify interested parties
            }
        }
        
    
    }
    
    private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>,
                                        length: Int) -> Message? {
        //1
        guard let stringArray = String(bytesNoCopy: buffer,
                                       length: length,
                                       encoding: .ascii,
                                       freeWhenDone: true)?.components(separatedBy: ":"),
            let name = stringArray.first,
            let message = stringArray.last else {
                return nil
        }
        //2
        let messageSender:MessageSender = (name == self.username) ? .ourself : .someoneElse
        //3
        return Message(message: message, messageSender: messageSender, username: name)
    }
    
    func sendMessage(message: String) {
        let data = "msg:\(message)".data(using: .ascii)!
        
        _ = data.withUnsafeBytes { outputStream.write($0, maxLength: data.count) }
    }
    
    func stopChatSession() {
        inputStream.close()
        outputStream.close()
    }
}
