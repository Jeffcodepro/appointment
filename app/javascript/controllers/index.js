// app/javascript/controllers/index.js
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

// Carrega automaticamente todos os controllers em app/javascript/controllers
eagerLoadControllersFrom("controllers", application)

