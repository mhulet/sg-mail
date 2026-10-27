# SG Mail

Super Génial Mail : client mail multi-boîtes et multi-utilisateurs pour les clients de Super Génial.

- [Note de cadrage](docs/cadrage.md)

## Lancer en local

Prérequis : Ruby 3.4.10 (`.ruby-version` et `.tool-versions` pour asdf), PostgreSQL.

```sh
bin/setup --skip-server
cp .env.example .env   # puis remplir GOOGLE_CLIENT_ID et GOOGLE_CLIENT_SECRET
bin/rails sg_mail:staff EMAIL=toi@exemple.be NAME="Ton nom"   # affiche un mot de passe
bin/dev                # http://localhost:3000, avec Solid Queue
```

`sg_mail:staff` crée un compte de l'équipe Super Génial (création des clients). Les boîtes importées
pendant la phase 0 se retrouvent dans un client « Compte initial », dont ce compte devient admin.

## Clients, membres et isolation

- **Client** (`Account`) : une organisation (Semisto, Silvéa…). Ses boîtes et ses emails lui appartiennent.
- **Membres** : rôle admin (invite, gère les rôles, déconnecte les boîtes) ou membre. Un utilisateur peut
  appartenir à plusieurs clients. Les adresses de l'app sont préfixées par l'id du client : `/12/mailboxes`.
- **Invitations** : envoyées par email (lien valable 14 jours, aussi visible dans la page Membres).
  L'équipe Super Génial crée un client et invite son premier admin, sans voir ses emails.
- **Isolation** (décision D3), deux verrous :
  - `acts_as_tenant` filtre `Mailbox`, `MailFolder` et `Message` sur le client courant, et refuse toute
    requête sans client ;
  - la Row Level Security de Postgres ne rend que les lignes du client fixé sur la connexion
    (`sg_mail.account_id`, voir `Tenancy`). Les tâches système qui traversent les clients passent par
    `Tenancy.across_accounts`.
  - Un superutilisateur Postgres échappe à la RLS : en production, l'app doit se connecter avec un rôle
    ordinaire (propriétaire des tables, sans `SUPERUSER` ni `BYPASSRLS`). Les tests vérifient la RLS
    avec un rôle ordinaire.
  - Les règles RLS vivent dans `db/structure.sql` (pas de `schema.rb` pour la base principale).

## Boîtes et partage

- Une boîte connectée est **perso** : seule la personne qui l'a connectée la voit, même les admins du
  client ne la voient pas. Elle peut la **partager** (page « Partage » de la boîte) avec d'autres membres :
  lecture, lecture et envoi, ou gestion (partage et déconnexion). Il reste toujours au moins un gestionnaire.
- Quitter un client retire ses accès aux boîtes de ce client.

## Synchros

- Les synchros tournent dans Solid Queue, hors du processus web : `bin/dev` lance Puma avec son
  superviseur Solid Queue (`SOLID_QUEUE_IN_PUMA`). On peut aussi lancer les jobs à part avec `bin/jobs`.
- **IMAP, temps réel** : `bin/idle` (ou `bin/rails sg_mail:idle`) garde une connexion IDLE par boîte IMAP
  et lance une synchro dès qu'un message arrive ou disparaît. `bin/dev` le lance aussi
  (`SKIP_IMAP_IDLE=1` pour s'en passer). En production, c'est le rôle `idle` de Kamal.
- **Gmail, temps réel** : avec `GMAIL_PUBSUB_TOPIC` et `GMAIL_PUBSUB_TOKEN`, chaque synchro (re)lance
  `users.watch` (valable 7 jours) et Google prévient `/webhooks/gmail?token=…` à chaque changement.
  Réglage côté Google Cloud, une fois, quand l'app a une adresse publique :
  1. activer l'API Pub/Sub et créer le sujet (ex. `projects/<projet>/topics/sg-mail-gmail`) ;
  2. donner le rôle « Éditeur Pub/Sub » sur ce sujet à `gmail-api-push@system.gserviceaccount.com` ;
  3. créer un abonnement **push** vers `https://<hôte>/webhooks/gmail?token=<GMAIL_PUBSUB_TOKEN>`.
- `SyncAllMailboxesJob` relance toutes les boîtes toutes les 5 minutes (`config/recurring.yml`) :
  filet de sécurité si une notification se perd, et seule synchro Gmail en local (pas d'adresse publique).
- À la main : bouton « Synchroniser » sur une boîte, ou `bin/rails sg_mail:sync` / `sg_mail:watch`.
- `GMAIL_IMPORT_LIMIT` / `IMAP_IMPORT_LIMIT` limitent l'import initial pendant les essais.

## Phase 0 : preuve technique

Objectif : connecter une boîte Gmail (OAuth, API Gmail) et une boîte IMAP, importer puis synchroniser.
Terminée le 27 octobre 2026.

- **Gmail** : « Connecter une boîte Google », accepter l'écran « app non vérifiée » (Paramètres avancés → Continuer). L'import démarre tout de suite.
- **IMAP** : « Connecter une boîte IMAP », serveur + identifiants (mot de passe d'application si la validation en deux étapes est active).

### Comment ça marche

- `GmailSync` : import initial paginé et reprenable (`sync_state`), puis `history.list` à partir du dernier `historyId`. Réimport complet si l'historique a expiré. Lots de 25 messages, avec attente en cas de quota dépassé.
- `ImapSync` : INBOX + dossier Envoyés, reprise par UID, remise à zéro si `UIDVALIDITY` change, suppressions détectées. `EXAMINE` + `BODY.PEEK` : la synchro ne marque jamais un message comme lu.
- `MessageParser` : en-têtes, corps texte/HTML convertis en UTF-8, pièces jointes détectées.
- Jetons OAuth et mots de passe IMAP chiffrés (Active Record Encryption ; clés dérivées de `secret_key_base` en local).

### Tests

```sh
bin/rails test
# Test IMAP de bout en bout contre un vrai serveur (ex. Dovecot local) :
IMAP_TEST_HOST=127.0.0.1 IMAP_TEST_PORT=1143 IMAP_TEST_USER=… IMAP_TEST_PASSWORD=… IMAP_TEST_SSL=0 bin/rails test
```
