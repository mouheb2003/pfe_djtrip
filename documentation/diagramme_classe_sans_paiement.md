# Diagramme De Classes DJTrip Sans Paiement

Ce diagramme represente le modele metier principal du backend DJTrip.

Le systeme de paiement est volontairement exclu. Les classes `Payment` et `Invoice` ne sont pas representees.

```mermaid
classDiagram
direction LR

class User {
  +ObjectId _id
  +String fullname
  +Number age
  +String num_tel
  +String email
  +String mot_de_passe
  +String avatar
  +String cover_photo
  +String bio
  +String pays_origine
  +String langue_preferee
  +String[] centres_interet
  +Boolean profileVisibility
  +Boolean allowDirectMessages
  +Boolean allowPhoneCalls
  +String accountStatus
  +Boolean emailVerified
  +String googleId
  +String facebookId
  +Number wallet_balance
  +ObjectId[] favorites
  +Object fcmTokens
  +Boolean is_onboarded
  +Boolean is_approved
  +String signup_method
}

class Touriste {
  +ObjectId user
  +String[] centres_interet
  +String langue_preferee
}

class Organisator {
  +ObjectId user
  +String[] types_activites
  +ObjectId[] liste_activites
  +Number note_moyenne
  +Number nombre_avis
  +String[] langues_proposees
  +String description
}

class Admin {
  +String managedBy
}

class Activite {
  +ObjectId _id
  +String titre
  +String description
  +String type_activite
  +String categorie
  +ObjectId organisateur_id
  +String lieu
  +Object coordonnees
  +String location_type
  +Object[] itineraire
  +Number duree
  +Number prix
  +Number capacite_max
  +String[] langues_disponibles
  +String[] photos
  +String niveau_difficulte
  +Date date_debut
  +Date date_fin
  +String statut
  +Number note_moyenne
  +Number nombre_avis
  +Number nombre_reservations
  +ObjectId[] bookmarked_by
}

class Inscription {
  +ObjectId touriste_id
  +ObjectId activite_id
  +ObjectId organisateur_id
  +String statut
  +Number nombre_participants
  +String message_touriste
  +String message_organisateur
  +Date date_demande
  +Date date_reponse
  +Number prix_total
  +String qr_token
  +Date qr_used_at
  +Boolean hasReviewed
  +Object reviewReminder
  +Object bookingReminder
  +Object cancellationPolicy
  +approve()
  +reject()
  +cancel()
  +marquerCommeUtilise()
  +marquerCommeReviewed()
  +checkBookingOverlap()
}

class Avis {
  +ObjectId touriste_id
  +ObjectId activite_id
  +ObjectId organisateur_id
  +String type
  +Number note
  +String commentaire
  +String[] tags
  +ObjectId inscription_id
}

class Lieu {
  +String name
  +String slug
  +String type
  +String address
  +String city
  +Object coordinates
  +String main_image
  +String[] gallery
  +String short_description
  +String long_description
  +String[] amenities
  +String opening_hours
  +Number rating
  +Number review_count
  +Boolean is_featured
  +String[] tags
  +ObjectId[] bookmarked_by
}

class Post {
  +ObjectId author_id
  +String content
  +String[] image_urls
  +String post_type
  +String audience
  +String location_label
  +String[] hashtags
  +String[] mentions
  +ObjectId[] liked_by
  +Object[] reactions
  +Number comments_count
  +ObjectId[] bookmarked_by
  +Boolean is_active
  +getCommentsCount()
}

class Comment {
  +ObjectId post_id
  +ObjectId user_id
  +String content
  +ObjectId parent_comment_id
  +Number depth
  +Number replies_count
  +ObjectId[] mentions
  +Object[] reactions
  +Boolean is_active
  +canEdit()
  +canDelete()
  +getCommentCount()
}

class Message {
  +ObjectId sender_id
  +ObjectId receiver_id
  +String content
  +String message_type
  +String media_url
  +Boolean is_read
  +Boolean is_edited
}

class Follow {
  +ObjectId follower_id
  +ObjectId following_id
  +isFollowing()
  +getFollowersCount()
  +getFollowingCount()
}

class Notification {
  +ObjectId user_id
  +String type
  +String title
  +String message
  +Object data
  +Boolean is_read
  +String priority
  +String related_entity_type
  +ObjectId related_entity_id
  +createNotification()
  +getUserNotifications()
  +markAsRead()
  +getUnreadCount()
}

class NotificationPreference {
  +ObjectId user_id
  +Boolean push_enabled
  +Boolean email_enabled
  +Object preferences
  +Object quiet_hours
  +Object device_settings
  +isPushEnabled()
  +isEmailEnabled()
  +isQuietHours()
}

class NotificationAnalytics {
  +ObjectId notification_id
  +ObjectId user_id
  +String notification_type
  +String delivery_status
  +Boolean opened
  +Boolean clicked
  +String device_type
  +recordDelivery()
  +recordOpen()
  +recordClick()
}

class Appeal {
  +ObjectId user_id
  +String subject
  +String message
  +String status
  +String admin_response
  +ObjectId admin_id
  +String[] attachments
  +Object metadata
  +updateStatus()
  +canBeUpdated()
}

class CheckinLog {
  +ObjectId bookingId
  +ObjectId organiserId
  +ObjectId touristId
  +ObjectId activityId
  +String status
  +String failureReason
  +String qrData
  +Date timestamp
  +createLog()
  +getByOrganiser()
  +getByActivity()
  +getStats()
}

class ActivityLog {
  +ObjectId actorId
  +String actorName
  +String action
  +String targetType
  +ObjectId targetId
  +Object metadata
  +String description
}

User <|-- Touriste
User <|-- Organisator
User <|-- Admin

Organisator "1" --> "0..*" Activite : cree
Touriste "1" --> "0..*" Inscription : reserve
Activite "1" --> "0..*" Inscription : contient
Organisator "1" --> "0..*" Inscription : recoit

Touriste "1" --> "0..*" Avis : redige
Avis "0..*" --> "0..1" Activite : evalue
Avis "0..*" --> "0..1" Organisator : evalue
Avis "0..1" --> "1" Inscription : justifie

User "1" --> "0..*" Post : publie
Post "1" --> "0..*" Comment : contient
User "1" --> "0..*" Comment : ecrit
Comment "0..1" --> "0..*" Comment : reponses

User "1" --> "0..*" Message : envoie
User "1" --> "0..*" Message : recoit
User "1" --> "0..*" Follow : follower
User "1" --> "0..*" Follow : following

User "1" --> "0..*" Notification : recoit
User "1" --> "1" NotificationPreference : configure
Notification "1" --> "0..*" NotificationAnalytics : mesure

User "1" --> "0..*" Appeal : soumet
Admin "1" --> "0..*" Appeal : traite

Inscription "1" --> "0..*" CheckinLog : audit
Activite "1" --> "0..*" CheckinLog : audit
User "1" --> "0..*" ActivityLog : effectue

User "0..*" --> "0..*" Lieu : bookmark
User "0..*" --> "0..*" Activite : favorite/bookmark
User "0..*" --> "0..*" Post : like/bookmark
```

