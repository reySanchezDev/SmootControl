# Features

Cada feature debe mantener la estructura Clean Architecture definida en
`rules.md`:

```text
domain/entities
domain/repositories
domain/services
data/models
data/datasources
data/repositories
presentation/bloc
presentation/pages
presentation/widgets
```

No se debe importar `data` desde `presentation` ni desde `domain`.
