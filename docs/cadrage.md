# SG Mail : note de cadrage

*Version 0.1, 27 octobre 2026. Document de travail, rien n'est encore codé.*

## 1. En une phrase

SG Mail (Super Génial Mail) est un client mail web, gratuit, réservé aux clients de Super Génial, qui rassemble plusieurs boîtes (Google et IMAP), personnelles et partagées, avec un statut de lecture **par personne**, des tâches nées des emails, et une ouverture native vers Claude (MCP, CLI, API) et vers les outils de gestion des clients (MySemisto, etc.).

Inspiration : Hey.com pour l'ergonomie, Front/Missive pour le travail à plusieurs sur une même boîte. Pas de calendrier.

## 2. Verdict de faisabilité

| Sujet | Faisable ? | Point d'attention |
|---|---|---|
| Boîtes Google sans Cloud Console par client | Oui | Une seule app OAuth côté SG Mail. Les scopes Gmail sont « restreints » : écran « app non vérifiée » et plafond de 100 utilisateurs tant que Google n'a pas vérifié l'app (voir §3). |
| Boîtes IMAP/SMTP classiques | Oui | Synchronisation à soigner (IDLE, UIDVALIDITY). Mot de passe chiffré. |
| Statut de lu par utilisateur | Oui | C'est une donnée SG Mail, indépendante du drapeau « lu » de Google/IMAP. |
| Emails transformés en tâches | Oui | Simple, côté SG Mail. |
| MCP + CLI + API | Oui | Une API unique, le MCP et le CLI s'appuient dessus. |
| Brancher le MCP de MySemisto dans SG Mail | Oui | Deux chemins, dont un qui marche **dès le premier jour sans dev** (voir §7). |
| Confidentialité multi-client | Oui | Isolation par client + chiffrement des secrets. Choix du mode d'isolation à trancher (§4). |

## 3. Connexion des boîtes Google

### 3.1 Comment font les outils de prospection

Les outils type lemlist ou Lemwarm ont **une seule** app OAuth chez Google, enregistrée par l'éditeur. L'utilisateur clique « Se connecter avec Google », accepte, c'est tout. Aucun client ne touche à la Cloud Console. SG Mail peut faire exactement pareil : **un projet Google Cloud unique, géré par Super Génial**, configuré une fois.

Ce que ces éditeurs ont fait en plus, c'est passer la **vérification Google**, obligatoire pour les scopes Gmail dits « restreints ».

### 3.2 Les scopes et ce qu'ils impliquent

| Scope | Usage | Classe Google |
|---|---|---|
| `gmail.modify` | Lire, classer, marquer, envoyer (tout sauf suppression définitive) | Restreint |
| `gmail.send` seul | Envoyer uniquement | Sensible |
| `https://mail.google.com/` | Accès IMAP/SMTP via OAuth (XOAUTH2) | Restreint |

SG Mail a besoin de lire : on est donc forcément en **scope restreint** (`gmail.modify` recommandé).

### 3.3 Trois paliers possibles

1. **App en production, non vérifiée (MVP).** Fonctionne tout de suite. Chaque utilisateur voit une fois l'écran « Google n'a pas validé cette application » et clique « Paramètres avancés → Continuer ». Plafond : 100 utilisateurs Google au total sur la vie de l'app. Les jetons n'expirent pas (contrairement au mode « Test », où ils expirent après 7 jours : à éviter).
2. **Workspace qui fait confiance à l'app.** Pour les domaines Google Workspace (semisto.org, probablement les clients), l'admin du domaine peut déclarer l'app SG Mail comme « approuvée » dans la console d'administration (Sécurité → Contrôle des accès aux API → Applications configurées, via l'ID client). Plus d'écran d'avertissement pour ce domaine. Variante plus forte : délégation au niveau du domaine (compte de service), sans consentement individuel, utile pour les boîtes partagées.
3. **Vérification Google + audit CASA.** Nécessaire au-delà de 100 utilisateurs ou pour un parcours sans avertissement pour des comptes Gmail grand public. Demande : domaine vérifié, page de confidentialité, vidéo de démo, puis audit de sécurité CASA (niveau 2) par un auditeur agréé, **à renouveler chaque année**. Compter quelques semaines et un budget de l'ordre de quelques centaines à quelques milliers d'euros par an (à confirmer au moment voulu).

**Recommandation :** palier 1 pour démarrer, palier 2 pour les clientes en Workspace, palier 3 seulement si le nombre d'utilisateurs l'impose.

### 3.4 Alternative sans OAuth : IMAP + mot de passe d'application

Un compte Google avec validation en deux étapes peut générer un mot de passe d'application et se connecter en IMAP/SMTP classique. Avantages : aucune démarche Google. Limites : un admin Workspace peut l'interdire, l'utilisateur doit savoir le générer, et on perd l'API Gmail (notifications push, historique incrémental). Les extensions IMAP de Gmail (`X-GM-THRID`, `X-GM-LABELS`) compensent en partie.

**Recommandation :** filet de sécurité, pas voie principale.

### 3.5 Contraintes Google à respecter dès le départ

- **Politique « Limited Use »** : les données Gmail ne servent qu'aux fonctions visibles par l'utilisateur, jamais à la publicité ni à l'entraînement de modèles. Envoyer un email à Claude pour une fonction demandée par l'utilisateur est permis, à condition de le déclarer dans la politique de confidentialité.
- Notifications temps réel Gmail : `users.watch` + un sujet **Pub/Sub** dans le projet Google de SG Mail (un seul pour tous les clients).

## 4. Multi-tenant et confidentialité

Un **client** (tenant) = une organisation : Semisto, Silvéa, Super Génial… Un utilisateur peut appartenir à plusieurs clients (Michael chez Semisto et chez Super Génial).

### 4.1 Les trois options

| Option | Principe | Pour | Contre |
|---|---|---|---|
| A. Colonne `account_id` + RLS Postgres | Tables partagées, chaque ligne porte son client. `acts_as_tenant` côté Rails, et Row Level Security côté Postgres comme deuxième verrou. | Simple, une seule migration, jobs et recherche faciles, standard Rails. | L'isolation repose sur la discipline + RLS (bien configuré, c'est solide). |
| B. Un schéma Postgres par client (`ros-apartment`) | Ce que tu évoquais. Chaque client a ses tables dans son schéma. | Isolation visible, export/suppression d'un client facile. | Migrations × N, gem peu maintenue, frictions avec Solid Queue et le pool de connexions, requêtes transverses pénibles. |
| C. Une base SQLite par client (`activerecord-tenanted`, 37signals) | Un fichier de base par client, approche récente de 37signals (les auteurs de Hey). | Isolation physique maximale, sauvegarde/suppression par fichier. | Jeune, impose SQLite, moins d'outillage. |

**Recommandation : A.** Pour une poignée de clients, elle donne une isolation réelle (RLS refuse toute ligne d'un autre client même en cas de bug applicatif) sans le coût opérationnel de B. Si la séparation physique est un argument commercial fort pour tes clientes, C est plus moderne que B.

### 4.2 Mesures de confidentialité, quel que soit le choix

- Jetons OAuth et mots de passe IMAP chiffrés (Active Record Encryption), jamais exposés par l'API.
- Hébergement en Europe (Infomaniak ou Hetzner), disque chiffré, sauvegardes chiffrées.
- Journal d'accès : qui a ouvert quel email, quand (c'est aussi ce qui alimente « lu par »).
- Super Génial est sous-traitant au sens du RGPD : un court accord de traitement par client.
- Suppression complète d'un client ou d'une boîte à la demande.

## 5. Modèle de données

```
Account (client)                       ex. Semisto
 ├─ Membership (user, role: admin|member)
 ├─ Mailbox (provider: gmail|imap, address, shared?, credentials chiffrées, sync_state)
 │   └─ MailboxAccess (user, can_send?, can_manage?)
 ├─ Conversation (fil)                 regroupe les Messages
 │   ├─ Message (provider_id, message_id, in_reply_to, from, to, cc, subject, body, sent_at)
 │   │   └─ Attachment (Active Storage, téléchargé à la demande)
 │   ├─ Reading (user, message, read_at)          ← statut de lu par personne
 │   ├─ ConversationState (user, bucket, reply_later?, set_aside?, archived?)
 │   ├─ Note (user, body)                          ← note interne, invisible du correspondant
 │   └─ Assignment (user)                          ← qui s'en occupe
 ├─ Task (title, status, due_on, assignee, conversation, message, external_ref)
 ├─ Contact (email, name, screening: pending|accepted|blocked)
 └─ Integration (user, kind: mcp|api, url, jetons chiffrés)   ← MySemisto, etc.

User (global, hors client) : email, nom, passkey/mot de passe, jetons API
```

Points clés :

- **Le lu est une ligne `Reading` par utilisateur et par message.** L'interface affiche « Lu par Michael, pas encore par Mohammad ». Le drapeau « lu » de Gmail est une autre information, gérée selon la décision D4.
- La boîte partagée appartient au client, pas à une personne : le jeton est attaché à la `Mailbox`. Une personne la connecte une fois, les autres y accèdent via `MailboxAccess`.
- `ConversationState` porte les fonctions façon Hey, **par utilisateur** : chacun classe sa vue sans gêner l'autre.
- `Task.external_ref` garde le lien vers la tâche créée dans MySemisto, pour l'afficher dans le fil.

## 6. Synchronisation et envoi

- **Gmail** : import initial paginé, puis `history.list` incrémental déclenché par les notifications Pub/Sub. Les fils Gmail (`threadId`) donnent les conversations.
- **IMAP** : gem `net-imap` (standard Ruby), connexion IDLE persistante par boîte dans un processus dédié, reprise via `UIDVALIDITY`/`UID` (et `CONDSTORE` quand le serveur le permet). Conversations reconstruites via `Message-ID`/`References`.
- **Envoi** : API Gmail (le message apparaît dans « Envoyés ») ; SMTP + `APPEND` dans le dossier Envoyés pour IMAP.
- Les corps sont stockés chez SG Mail (nécessaire pour la recherche et la vitesse) ; les pièces jointes sont téléchargées à la demande puis mises en cache.
- Écritures vers le fournisseur (archiver, étiqueter) en tâche de fond, avec reprise en cas d'erreur.

## 7. MCP, CLI, API et outils tiers

### 7.1 Une API, trois portes

- **API REST JSON** (`/api/v1`), source unique de vérité. Authentification par jeton personnel (CLI, scripts) ou OAuth 2.1 (Doorkeeper) pour le MCP.
- **Serveur MCP** dans l'app Rails (SDK MCP officiel en Ruby, transport HTTP « streamable », endpoint `/mcp`), connectable dans Claude comme connecteur personnalisé. Outils envisagés : `search_conversations`, `get_conversation`, `mark_read`, `draft_reply`, `send_draft`, `create_task`, `list_tasks`, `assign`, `add_note`. Par défaut Claude **rédige des brouillons** ; l'envoi demande une action explicite.
- **CLI** `sg` (gem Ruby avec Thor), sortie texte ou `--json` pour Claude Code : `sg inbox`, `sg show 123`, `sg task add 123 "Relancer le devis"`, `sg reply 123 --draft`.

### 7.2 Agir sur MySemisto depuis un fil

**Chemin 1, sans aucun développement (disponible dès que le MCP SG Mail existe) :** dans Claude, connecter à la fois le MCP SG Mail et le MCP MySemisto. « Lis le dernier mail de formation@ et crée la tâche correspondante dans le projet Academy » : Claude fait le pont entre les deux outils.

**Chemin 2, dans l'interface SG Mail (phase 2) :** un panneau « Assistant » dans chaque fil. SG Mail appelle l'API Claude en lui passant le fil et les serveurs MCP que l'utilisateur a branchés (l'API Anthropic accepte directement des serveurs MCP distants avec leur jeton : SG Mail n'a pas à réimplémenter un client MCP complet). L'utilisateur branche MySemisto une fois via OAuth, le jeton est stocké chiffré dans `Integration`. À noter : les appels à l'API Claude sont payants pour Super Génial.

Sans MCP, la même `Integration` peut viser une API REST classique (webhook ou appel configuré).

## 8. Stack recommandée

- **Rails 8**, Ruby 3.4, PostgreSQL 17.
- **Hotwire** (Turbo + Stimulus) : c'est la stack de Hey, idéale pour une interface rapide sans SPA.
- **Solid Queue / Solid Cache / Solid Cable** ; un processus séparé pour les connexions IMAP IDLE.
- Authentification : générateur d'auth Rails 8 + passkeys ; invitations par client.
- Recherche : full-text Postgres (`pg_search`) au départ.
- Déploiement : **Kamal** sur un VPS européen (Infomaniak ou Hetzner).
- Mobile : PWA au départ, Hotwire Native plus tard si besoin.
- Gems clés : `google-apis-gmail_v1`, `net-imap`, `mail`, `acts_as_tenant`, `doorkeeper`, `mcp`, `anthropic` (phase 2).

## 9. MVP proposé

**Phase 0, preuve technique (1 à 2 semaines).** Projet Google, connexion d'une boîte Gmail en OAuth et d'une boîte IMAP, import et synchro d'une boîte réelle (formation@semisto.org).

**Phase 1, MVP utilisable par Semisto.**
1. Clients, utilisateurs, invitations, rôles.
2. Connexion de boîtes Gmail et IMAP, perso et partagées, avec droits d'accès.
3. Boîte unifiée + vue par boîte, lecture de fils, pièces jointes.
4. Statut de lu par personne (« lu par… »).
5. Répondre, transférer, rédiger, avec choix de l'adresse d'envoi.
6. Tâches créées depuis un email, liste « mes tâches ».
7. Notes internes et assignation d'un fil à une personne.
8. Recherche.
9. API + MCP + CLI (lecture, tâches, brouillons).

**Phase 2, l'esprit Hey et l'assistant.** Screener (approbation des nouveaux expéditeurs), Imbox / Feed / Paper Trail, Reply Later, Set Aside, assistant Claude dans le fil avec MCP tiers.

**Phase 3, ouverture.** Vérification Google + CASA si plus de 100 utilisateurs, application mobile.

## 10. Risques principaux

| Risque | Parade |
|---|---|
| Google durcit sa politique ou refuse la vérification | IMAP + mot de passe d'application en secours ; rester sous 100 utilisateurs. |
| Synchro IMAP fragile selon les hébergeurs | Tester tôt avec les vrais fournisseurs des clientes. |
| Dispersion : le périmètre ressemble à Hey + Front + un assistant IA | Tenir le MVP de la phase 1, le reste attend un usage réel. |
| Données sensibles chez Super Génial | Chiffrement, hébergement UE, accord de traitement, journal d'accès. |

## 11. Décisions ouvertes à valider par Michael

| # | Question | Recommandation |
|---|---|---|
| D1 | Accepter l'écran « app non vérifiée » et le plafond de 100 utilisateurs Google pour le MVP ? | Oui |
| D2 | formation@semisto.org est-il un vrai compte Google (avec mot de passe) et non un Google Group ? Un groupe n'a pas de boîte à connecter. | À vérifier |
| D3 | Isolation par `account_id` + RLS Postgres plutôt que des schémas séparés ? | Oui (option A) |
| D4 | Laisser le drapeau « lu » de Gmail tel quel (SG Mail gère son propre lu par personne) ? Alternative : le marquer lu dès qu'une personne a lu. | Oui, ne pas y toucher |
| D5 | Stocker les corps des emails chez SG Mail (indispensable pour la recherche et le MCP) ? | Oui |
| D6 | Héberger chez Infomaniak (Suisse, cohérent avec tes outils actuels) ? | Oui |
| D7 | Envoi d'emails dès le MVP (et pas seulement lecture + tâches) ? | Oui |
| D8 | Assistant Claude intégré (API payée par Super Génial) reporté en phase 2, le chemin « Claude + deux MCP » suffisant au départ ? | Oui |
