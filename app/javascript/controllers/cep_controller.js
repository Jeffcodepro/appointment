// app/javascript/controllers/cep_controller.js
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="cep"
export default class extends Controller {
  static targets = ["cepField", "cityField", "stateField"]

  search() {
    const cep = this.cepFieldTarget.value.replace(/\D/g, ''); // Remove non-digit characters

    if (cep.length === 8) {
      this.fetchAddress(cep);
    }
  }

  fetchAddress(cep) {
    fetch(`https://viacep.com.br/ws/${cep}/json/`)
      .then(response => response.json())
      .then(data => {
        if (!data.erro) {
          this.cityFieldTarget.value = data.localidade;
          this.stateFieldTarget.value = data.uf;
        } else {
          // Handle error, e.g., clear fields or show a message
          this.cityFieldTarget.value = "";
          this.stateFieldTarget.value = "";
          console.error("CEP não encontrado ou inválido.");
        }
      })
      .catch(error => {
        console.error("Erro ao tentar buscar CEP:", error);
      });
  }
}
