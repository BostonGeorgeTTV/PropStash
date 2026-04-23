# PropStash
PropStash trasforma props e zone target in stash modulari per FiveM.

<img width="1672" height="941" alt="propstash" src="https://github.com/user-attachments/assets/b6e7ceb7-35ed-41e8-8aeb-f311b9b8a266" />


# propstash

Prop stash modulare per FiveM con `ox_inventory`, `ox_target`, `ox_lib` e bridge per `ESX`, `QBCore` e `Qbox`.

- l'accesso allo stash è controllato da un hook `openInventory`
- la whitelist/blacklist degli item depositabili è controllata da `swapItems`
- il pagamento quando un player trascina fuori un item dallo stash è gestito da `swapItems`
- i manager possono cambiare il prezzo di ogni stack da un piccolo menu separato
- il target può essere applicato a **tutti i prop di un modello**, a **una o più box zone**, oppure a **entrambe le cose**
- ogni configurazione genera **uno stash condiviso per quella config entry**

## Dipendenze

- ox_lib
- ox_inventory
- ox_target
- un framework supportato: ESX, QBCore o Qbox

## Installazione

1. Copia la cartella `propstash` nelle tue resources.
2. Assicurati che parta **dopo** `ox_lib`, `ox_inventory`, `ox_target` e il framework.
3. Aggiungi `ensure propstash` al `server.cfg`.
4. Configura `config.lua`.

## Config target

Ogni stash può definire:

- `target.mode = 'model'`
- `target.mode = 'boxzone'`
- `target.mode = 'both'`

### Esempio solo model

```lua
Config.Stashes = {
    news_display = {
        label = 'Espositore Giornali',
        target = {
            mode = 'model',
            model = `prop_news_disp_01a`,
            distance = 2.0,
            icon = 'fa-solid fa-newspaper',
            openLabel = 'Apri espositore',
            pricesLabel = 'Vedi prezzi',
            manageLabel = 'Gestisci prezzi',
        },
        slots = 30,
        maxWeight = 30000,
        moneyAccount = 'cash',
        publicAccess = true,
        managerBypassPrice = true,
        manageAccess = {
            jobs = {
                weazelnews = 0,
            },
        },
        allowedItems = {
            newspaper = {
                minPrice = 0,
                maxPrice = 250,
                defaultPrice = 0,
                label = 'Giornale',
            },
        },
    },
}
```

### Esempio solo boxzone

```lua
Config.Stashes = {
    news_counter = {
        label = 'Banco Giornali',
        target = {
            mode = 'boxzone',
            distance = 2.0,
            icon = 'fa-solid fa-newspaper',
            openLabel = 'Apri banco',
            zones = {
                {
                    id = 'weazel_frontdesk',
                    coords = vec3(-598.84, -929.88, 23.86),
                    size = vec3(1.8, 1.2, 2.2),
                    rotation = 0.0,
                    debug = false,
                }
            }
        },
        slots = 30,
        maxWeight = 30000,
        manageAccess = {
            jobs = {
                weazelnews = 0,
            },
        },
        allowedItems = {
            newspaper = {
                minPrice = 0,
                maxPrice = 250,
                defaultPrice = 0,
            },
        },
    },
}
```

### Esempio both

```lua
Config.Stashes = {
    news_display = {
        label = 'Espositore Giornali',
        target = {
            mode = 'both',
            model = `prop_news_disp_01a`,
            distance = 2.0,
            icon = 'fa-solid fa-newspaper',
            openLabel = 'Apri espositore',
            zones = {
                {
                    id = 'weazel_frontdesk',
                    coords = vec3(-598.84, -929.88, 23.86),
                    size = vec3(1.8, 1.2, 2.2),
                    rotation = 0.0,
                }
            }
        },
        slots = 30,
        maxWeight = 30000,
        manageAccess = {
            jobs = {
                weazelnews = 0,
            },
        },
        allowedItems = {
            newspaper = {
                minPrice = 0,
                maxPrice = 250,
                defaultPrice = 0,
            },
        },
    },
}
```

## Logica accessi

### `publicAccess`

Se `true`, tutti possono aprire lo stash e trascinare fuori item.

Se il prezzo dello stack è:
- `0`: l'item è gratis
- `> 0`: il player paga prima che il movimento venga autorizzato

### `manageAccess`

Chi passa `manageAccess` può:
- aprire lo stash
- depositare item dentro lo stash
- riorganizzare lo stash
- cambiare il prezzo degli stack
- opzionalmente prelevare gratis se `managerBypassPrice = true`

### Filtri supportati

`manageAccess` supporta:
- `jobs`
- `gangs`
- `groups`
- `licenses`
- `citizenids`
- `identifiers`

## Nota importante sulla condivisione

In questa variante il target è flessibile, ma **lo stash resta uno per ogni entry di `Config.Stashes`**.

Quindi:
- se usi `mode = 'model'`, tutti i prop di quel modello aprono lo stesso stash
- se usi `mode = 'boxzone'` con più zone, tutte quelle zone aprono lo stesso stash
- se usi `mode = 'both'`, props e box zone puntano allo stesso stash

Se vorrai fare un passo in più e avere **zone diverse con stash diversi**, si può aggiungere una variante `perZone`.

## Prezzo per stack

Il prezzo è salvato nei metadata dello stack con una chiave interna configurabile (`Config.MetadataKey`).

Se uno stack non ha ancora un prezzo nei metadata, viene usato `defaultPrice` definito per quell'item in config.

## UX dei prezzi

Lo stash viene aperto con l'UI nativa di `ox_inventory`, quindi per mostrare chiaramente i prezzi al player ho lasciato un'opzione target separata: `Vedi prezzi`.

## Accredito società

Lo script rimuove i soldi dal buyer, ma **non** accredita automaticamente una society. Per questo c'è un hook evento:

```lua
AddEventHandler('propstash:server:purchase', function(source, runtimeId, stashKey, itemName, count, totalPrice, moneyAccount)
    -- collega qui esx_society / qb-management / qbx_management / banca custom
end)
```

## Compatibilità legacy

Per non rompere la config precedente, il client prova ancora a leggere anche questi campi top-level:

- `model`
- `icon`
- `targetLabel`
- `pricesLabel`
- `manageLabel`
- `locations` (come alias legacy di `target.zones`)

Ma da ora in poi conviene usare `target = { ... }`.
