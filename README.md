# SG Mail

Super Génial Mail : client mail multi-boîtes et multi-utilisateurs pour les clients de Super Génial.

- [Note de cadrage](docs/cadrage.md)

## Phase 0 : preuve technique

Objectif : connecter une boîte Gmail (OAuth, API Gmail) et une boîte IMAP, importer puis synchroniser.
Pas encore de comptes, de multi-tenant ni d'authentification : l'app tourne en local uniquement.

### Lancer en local

Prérequis : Ruby 3.4.10 (`.ruby-version` et `.tool-versions` pour asdf), PostgreSQL.

```sh
bin/setup --skip-server
cp .env.example .env   # puis remplir GOOGLE_CLIENT_ID et GOOGLE_CLIENT_SECRET
bin/dev                # http://localhost:3000
```

- **Gmail** : « Connecter une boîte Google », accepter l'écran « app non vérifiée » (Paramètres avancés → Continuer). L'import démarre tout de suite.
- **IMAP** : « Connecter une boîte IMAP », serveur + identifiants (mot de passe d'application si la validation en deux étapes est active).
- **Synchro** : bouton « Synchroniser » sur une boîte, ou `bin/rails sg_mail:sync` (une fois) / `bin/rails sg_mail:watch` (toutes les 60 s).
- `GMAIL_IMPORT_LIMIT` / `IMAP_IMPORT_LIMIT` limitent l'import initial pendant les essais.

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
