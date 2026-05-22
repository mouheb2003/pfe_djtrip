# Sprint 4 - Communication et reseau social

## Diagramme de cas d'utilisation

```mermaid
flowchart LR

User([Utilisateur])

subgraph SYSTEM["DJTrip - Systeme de communication et reseau social"]
direction TB

subgraph MSG["Messagerie"]
direction LR
M1(("Consulter conversations"))
M2(("Envoyer message"))
M3(("Envoyer media"))
M4(("Modifier message"))
M5(("Supprimer message"))
M6(("Archiver conversation"))
M7(("Desarchiver conversation"))
M8(("Vider conversation"))
M9(("Bloquer utilisateur"))
M10(("Debloquer utilisateur"))
M11(("Muter conversation"))
M12(("Demuter conversation"))
Socket[[Socket.IO]]
Cloud[[Cloudinary]]

M3 -. include .-> M2
M3 -. include .-> Cloud
M2 -. include .-> Socket
M7 -. extend .-> M6
M10 -. extend .-> M9
M12 -. extend .-> M11
end

subgraph POST["Publications"]
direction LR
P1(("Consulter fil actualite"))
P2(("Creer publication"))
P3(("Modifier publication"))
P4(("Supprimer publication"))
P5(("Uploader image publication"))
P6(("Liker publication"))
P7(("Bookmarker publication"))
P8(("Masquer publication"))

P2 -. include .-> P5
P5 -. include .-> Cloud
P6 -. extend .-> P1
P7 -. extend .-> P1
P8 -. extend .-> P1
end

subgraph COM["Commentaires"]
direction LR
C1(("Consulter commentaires"))
C2(("Ajouter commentaire"))
C3(("Repondre commentaire"))
C4(("Modifier commentaire"))
C5(("Supprimer commentaire"))
C6(("Reagir commentaire"))
C7(("Consulter reponses"))

C3 -. extend .-> C2
C2 -. extend .-> C1
C4 -. extend .-> C1
C5 -. extend .-> C1
C6 -. extend .-> C1
C7 -. extend .-> C1
end

subgraph SOC["Relations sociales"]
direction LR
F1(("Suivre utilisateur"))
F2(("Ne plus suivre utilisateur"))
F3(("Consulter followers"))
F4(("Consulter following"))

F2 -. extend .-> F1
end

end

User --> M1
User --> M2
User --> M4
User --> M5
User --> M6
User --> M8
User --> M9
User --> M11

User --> P1
User --> P2
User --> P3
User --> P4

User --> C1
User --> C2

User --> F1
User --> F3
User --> F4
```

## Diagrammes de sequence

### M1 - Consulter conversations

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Ouvrir messagerie
  F->>S: GET /messages/conversations
  S->>S: Verifier token utilisateur
  S->>DB: Recuperer conversations utilisateur
  DB-->>S: Liste conversations
  S-->>F: Retourner conversations
  F-->>U: Afficher conversations
```

### M2 - Envoyer message

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB
  participant Socket as Socket.IO

  U->>F: Ecrire message texte
  F->>S: POST /messages/with/:partnerId
  S->>S: Verifier token utilisateur
  S->>DB: Enregistrer message
  DB-->>S: Message sauvegarde
  S->>Socket: Emettre message en temps reel
  S-->>F: Retourner message envoye
  F-->>U: Afficher message
```

### M3 - Envoyer media

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant Cloud as Cloudinary
  participant DB as MongoDB
  participant Socket as Socket.IO

  U->>F: Choisir image audio ou video
  F->>S: POST /messages/with/:partnerId/image ou audio ou video
  S->>S: Verifier token utilisateur
  S->>Cloud: Uploader media
  Cloud-->>S: URL media
  S->>DB: Enregistrer message media
  DB-->>S: Message sauvegarde
  S->>Socket: Emettre message media
  S-->>F: Retourner message media
  F-->>U: Afficher media envoye
```

### M4 - Modifier message

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Modifier contenu message
  F->>S: PUT /messages/:messageId
  S->>S: Verifier token utilisateur
  S->>DB: Verifier proprietaire message
  DB-->>S: Proprietaire confirme
  S->>DB: Mettre a jour message
  DB-->>S: Message modifie
  S-->>F: Retourner message modifie
  F-->>U: Afficher modification
```

### M5 - Supprimer message

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Demander suppression message
  F->>S: DELETE /messages/:messageId
  S->>S: Verifier token utilisateur
  S->>DB: Verifier proprietaire message
  S->>DB: Supprimer message
  DB-->>S: Suppression confirmee
  S-->>F: Message supprime
  F-->>U: Retirer message de la conversation
```

### M6 - Archiver conversation

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Archiver conversation
  F->>S: POST /messages/conversations/:partnerId/archive
  S->>S: Verifier token utilisateur
  S->>DB: Marquer conversation archivee
  DB-->>S: Conversation archivee
  S-->>F: Reponse succes
  F-->>U: Masquer conversation active
```

### M7 - Desarchiver conversation

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Restaurer conversation archivee
  F->>S: DELETE /messages/conversations/:partnerId/archive
  S->>S: Verifier token utilisateur
  S->>DB: Retirer etat archive
  DB-->>S: Conversation restauree
  S-->>F: Reponse succes
  F-->>U: Afficher conversation restauree
```

### M8 - Vider conversation

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Vider conversation
  F->>S: DELETE /messages/conversations/:partnerId/clear
  S->>S: Verifier token utilisateur
  S->>DB: Supprimer affichage des messages pour utilisateur
  DB-->>S: Conversation videe
  S-->>F: Reponse succes
  F-->>U: Afficher conversation vide
```

### M9 - Bloquer utilisateur

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Bloquer utilisateur
  F->>S: POST /messages/conversations/:partnerId/block
  S->>S: Verifier token utilisateur
  S->>DB: Ajouter utilisateur a la liste bloquee
  DB-->>S: Utilisateur bloque
  S-->>F: Reponse succes
  F-->>U: Afficher utilisateur bloque
```

### M10 - Debloquer utilisateur

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Debloquer utilisateur
  F->>S: DELETE /messages/conversations/:partnerId/block
  S->>S: Verifier token utilisateur
  S->>DB: Retirer utilisateur de la liste bloquee
  DB-->>S: Utilisateur debloque
  S-->>F: Reponse succes
  F-->>U: Afficher utilisateur debloque
```

### M11 - Muter conversation

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Muter conversation
  F->>S: POST /messages/conversations/:partnerId/mute
  S->>S: Verifier token utilisateur
  S->>DB: Ajouter conversation aux conversations mutees
  DB-->>S: Conversation mutee
  S-->>F: Reponse succes
  F-->>U: Afficher conversation mutee
```

### M12 - Demuter conversation

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Demuter conversation
  F->>S: DELETE /messages/conversations/:partnerId/mute
  S->>S: Verifier token utilisateur
  S->>DB: Retirer conversation des conversations mutees
  DB-->>S: Conversation demutee
  S-->>F: Reponse succes
  F-->>U: Afficher conversation active
```

### P1 - Consulter fil actualite

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Ouvrir fil actualite
  F->>S: GET /posts/feed
  S->>S: Verifier token utilisateur
  S->>DB: Recuperer publications visibles
  DB-->>S: Liste publications
  S-->>F: Retourner fil actualite
  F-->>U: Afficher publications
```

### P2 - Creer publication

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Rediger publication
  F->>S: POST /posts
  S->>S: Verifier token et role utilisateur
  S->>DB: Enregistrer publication
  DB-->>S: Publication creee
  S-->>F: Retourner publication
  F-->>U: Afficher publication creee
```

### P3 - Modifier publication

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Modifier publication
  F->>S: PUT /posts/:postId
  S->>S: Verifier token utilisateur
  S->>DB: Verifier proprietaire publication
  S->>DB: Mettre a jour publication
  DB-->>S: Publication modifiee
  S-->>F: Retourner publication modifiee
  F-->>U: Afficher modification
```

### P4 - Supprimer publication

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Supprimer publication
  F->>S: DELETE /posts/:postId
  S->>S: Verifier token utilisateur
  S->>DB: Verifier proprietaire publication
  S->>DB: Supprimer publication
  DB-->>S: Publication supprimee
  S-->>F: Reponse succes
  F-->>U: Retirer publication
```

### P5 - Uploader image publication

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant Cloud as Cloudinary

  U->>F: Choisir image publication
  F->>S: POST /posts/upload-image
  S->>S: Verifier token utilisateur
  S->>Cloud: Uploader image
  Cloud-->>S: URL image
  S-->>F: Retourner URL image
  F-->>U: Afficher image dans publication
```

### P6 - Liker publication

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Cliquer like
  F->>S: POST /posts/:postId/like
  S->>S: Verifier token utilisateur
  S->>DB: Ajouter ou retirer reaction
  DB-->>S: Etat reaction mis a jour
  S-->>F: Retourner nombre reactions
  F-->>U: Mettre a jour like
```

### P7 - Bookmarker publication

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Cliquer bookmark publication
  F->>S: POST /posts/:postId/bookmark
  S->>S: Verifier token utilisateur
  S->>DB: Ajouter ou retirer bookmark
  DB-->>S: Etat bookmark mis a jour
  S-->>F: Retourner etat bookmark
  F-->>U: Mettre a jour icone bookmark
```

### P8 - Masquer publication

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Masquer publication
  F->>S: POST /posts/:postId/hide
  S->>S: Verifier token utilisateur
  S->>DB: Mettre a jour visibilite publication
  DB-->>S: Publication masquee
  S-->>F: Reponse succes
  F-->>U: Retirer publication de l affichage
```

### C1 - Consulter commentaires

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Ouvrir commentaires publication
  F->>S: GET /comments/:postId/comments
  S->>S: Verifier token utilisateur
  S->>DB: Recuperer commentaires
  DB-->>S: Liste commentaires
  S-->>F: Retourner commentaires
  F-->>U: Afficher commentaires
```

### C2 - Ajouter commentaire

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Ecrire commentaire
  F->>S: POST /comments/:postId/comments
  S->>S: Verifier token utilisateur
  S->>DB: Enregistrer commentaire
  DB-->>S: Commentaire cree
  S-->>F: Retourner commentaire
  F-->>U: Afficher commentaire
```

### C3 - Repondre commentaire

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Repondre a un commentaire
  F->>S: POST /comments/:postId/comments avec parentCommentId
  S->>S: Verifier token utilisateur
  S->>DB: Verifier commentaire parent
  S->>DB: Enregistrer reponse
  DB-->>S: Reponse creee
  S-->>F: Retourner reponse
  F-->>U: Afficher reponse
```

### C4 - Modifier commentaire

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Modifier commentaire
  F->>S: PATCH /comments/:commentId
  S->>S: Verifier token utilisateur
  S->>DB: Verifier proprietaire commentaire
  S->>DB: Mettre a jour commentaire
  DB-->>S: Commentaire modifie
  S-->>F: Retourner commentaire modifie
  F-->>U: Afficher modification
```

### C5 - Supprimer commentaire

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Supprimer commentaire
  F->>S: DELETE /comments/:commentId
  S->>S: Verifier token utilisateur
  S->>DB: Verifier droit de suppression
  S->>DB: Supprimer commentaire
  DB-->>S: Commentaire supprime
  S-->>F: Reponse succes
  F-->>U: Retirer commentaire
```

### C6 - Reagir commentaire

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Reagir a un commentaire
  F->>S: POST /comments/:commentId/react
  S->>S: Verifier token utilisateur
  S->>DB: Ajouter ou modifier reaction
  DB-->>S: Reaction mise a jour
  S-->>F: Retourner reactions
  F-->>U: Afficher reaction
```

### C7 - Consulter reponses

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Ouvrir reponses commentaire
  F->>S: GET /comments/:commentId/replies
  S->>S: Verifier token utilisateur
  S->>DB: Recuperer reponses
  DB-->>S: Liste reponses
  S-->>F: Retourner reponses
  F-->>U: Afficher reponses
```

### F1 - Suivre utilisateur

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Cliquer suivre
  F->>S: POST /follow
  S->>S: Verifier token utilisateur
  S->>DB: Creer relation follow
  DB-->>S: Relation creee
  S-->>F: Reponse succes
  F-->>U: Afficher utilisateur suivi
```

### F2 - Ne plus suivre utilisateur

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Cliquer ne plus suivre
  F->>S: DELETE /follow
  S->>S: Verifier token utilisateur
  S->>DB: Supprimer relation follow
  DB-->>S: Relation supprimee
  S-->>F: Reponse succes
  F-->>U: Afficher utilisateur non suivi
```

### F3 - Consulter followers

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Consulter followers
  F->>S: GET /follow/followers/:userId
  S->>DB: Compter followers
  DB-->>S: Nombre followers
  S-->>F: Retourner nombre followers
  F-->>U: Afficher followers
```

### F4 - Consulter following

```mermaid
sequenceDiagram
  actor U as Utilisateur
  participant F as Application Flutter
  participant S as Serveur DJTrip
  participant DB as MongoDB

  U->>F: Consulter following
  F->>S: GET /follow/following/:userId
  S->>DB: Compter following
  DB-->>S: Nombre following
  S-->>F: Retourner nombre following
  F-->>U: Afficher following
```
