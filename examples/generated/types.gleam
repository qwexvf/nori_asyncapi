//// Generated from Chat v1.0.0

import gleam
import gleam/dynamic/decode.{type Decoder}
import gleam/json.{type Json}
import gleam/option.{type Option, None, Some}

pub type PresenceStatus {
  PresenceStatusOnline
  PresenceStatusAway
  PresenceStatusOffline
}

pub fn presence_status_from_string(
  value: String,
) -> Result(PresenceStatus, Nil) {
  case value {
    "online" -> gleam.Ok(PresenceStatusOnline)
    "away" -> gleam.Ok(PresenceStatusAway)
    "offline" -> gleam.Ok(PresenceStatusOffline)
    _ -> gleam.Error(Nil)
  }
}

pub fn presence_status_to_string(value: PresenceStatus) -> String {
  case value {
    PresenceStatusOnline -> "online"
    PresenceStatusAway -> "away"
    PresenceStatusOffline -> "offline"
  }
}

pub type ChatDeleted {
  ChatDeleted(message_id: String)
}

pub type ChatEdited {
  ChatEdited(message_id: String, text: String)
}

pub type Presence {
  Presence(status: PresenceStatus, user: String)
}

pub type RoomEvent {
  RoomEvent(at: String, detail: Option(String), kind: String)
}

pub type ChatSent {
  ChatSent(reply_to: Option(String), text: String, user: String)
}

pub fn presence_status_decoder() -> Decoder(PresenceStatus) {
  use value <- decode.then(decode.string)
  case presence_status_from_string(value) {
    gleam.Ok(variant) -> decode.success(variant)
    gleam.Error(_) -> decode.failure(PresenceStatusOnline, "PresenceStatus")
  }
}

pub fn chat_deleted_decoder() -> Decoder(ChatDeleted) {
  use message_id <- decode.field("messageId", decode.string)
  decode.success(ChatDeleted(message_id: message_id))
}

pub fn chat_edited_decoder() -> Decoder(ChatEdited) {
  use message_id <- decode.field("messageId", decode.string)
  use text <- decode.field("text", decode.string)
  decode.success(ChatEdited(message_id: message_id, text: text))
}

pub fn presence_decoder() -> Decoder(Presence) {
  use status <- decode.field("status", presence_status_decoder())
  use user <- decode.field("user", decode.string)
  decode.success(Presence(status: status, user: user))
}

pub fn room_event_decoder() -> Decoder(RoomEvent) {
  use at <- decode.field("at", decode.string)
  use detail <- decode.optional_field(
    "detail",
    None,
    decode.optional(decode.string),
  )
  use kind <- decode.field("kind", decode.string)
  decode.success(RoomEvent(at: at, detail: detail, kind: kind))
}

pub fn chat_sent_decoder() -> Decoder(ChatSent) {
  use reply_to <- decode.optional_field(
    "replyTo",
    None,
    decode.optional(decode.string),
  )
  use text <- decode.field("text", decode.string)
  use user <- decode.field("user", decode.string)
  decode.success(ChatSent(reply_to: reply_to, text: text, user: user))
}

pub fn encode_presence_status(value: PresenceStatus) -> Json {
  json.string(presence_status_to_string(value))
}

pub fn encode_chat_deleted(value: ChatDeleted) -> Json {
  json.object([
    #("messageId", json.string(value.message_id)),
  ])
}

pub fn encode_chat_edited(value: ChatEdited) -> Json {
  json.object([
    #("messageId", json.string(value.message_id)),
    #("text", json.string(value.text)),
  ])
}

pub fn encode_presence(value: Presence) -> Json {
  json.object([
    #("status", encode_presence_status(value.status)),
    #("user", json.string(value.user)),
  ])
}

pub fn encode_room_event(value: RoomEvent) -> Json {
  json.object([
    #("at", json.string(value.at)),
    #("detail", case value.detail {
      Some(v) -> json.string(v)
      None -> json.null()
    }),
    #("kind", json.string(value.kind)),
  ])
}

pub fn encode_chat_sent(value: ChatSent) -> Json {
  json.object([
    #("replyTo", case value.reply_to {
      Some(v) -> json.string(v)
      None -> json.null()
    }),
    #("text", json.string(value.text)),
    #("user", json.string(value.user)),
  ])
}
