package main

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"strings"

	"github.com/AlecAivazis/survey/v2"
)

type Script struct {
	Name string
	Desc string
}

func parseReadme(filename string) (map[string][]Script, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	categories := make(map[string][]Script)
	var currentCategory string
	scanner := bufio.NewScanner(file)
	reCategory := regexp.MustCompile(`^#+\s*.*`)
	for scanner.Scan() {
		line := scanner.Text()
		if reCategory.MatchString(line) {
			currentCategory = strings.TrimSpace(line)
			categories[currentCategory] = []Script{}
		} else if currentCategory != "" && strings.TrimSpace(line) != "" {
			parts := strings.Fields(line)
			if len(parts) > 0 {
				script := parts[0]
				desc := ""
				if len(parts) > 1 {
					desc = strings.Join(parts[1:], " ")
				}
				categories[currentCategory] = append(categories[currentCategory], Script{Name: script, Desc: desc})
			}
		}
	}
	return categories, scanner.Err()
}

func main() {
	categories, err := parseReadme("README.md")
	if err != nil {
		fmt.Println("Error al leer README.md:", err)
		return
	}

	var catKeys []string
	for k := range categories {
		catKeys = append(catKeys, k)
	}

	var selectedCat string
	promptCat := &survey.Select{
		Message: "Selecciona una categoría:",
		Options: catKeys,
		// La opción de búsqueda interactiva depende de la versión y configuración de survey.
	}
	survey.AskOne(promptCat, &selectedCat)

	scripts := categories[selectedCat]
	if len(scripts) == 0 {
		fmt.Println("No hay scripts en esta categoría")
		return
	}

	var scriptChoices []string
	for _, s := range scripts {
		scriptChoices = append(scriptChoices, fmt.Sprintf("%s - %s", s.Name, s.Desc))
	}

	var selectedScript string
	promptScript := &survey.Select{
		Message: "Selecciona un script:",
		Options: scriptChoices,
		// survey permite buscar escribiendo letras.
	}
	survey.AskOne(promptScript, &selectedScript)

	parts := strings.SplitN(selectedScript, " - ", 2)
	if len(parts) < 2 {
		fmt.Println("Selección inválida")
		return
	}
	fmt.Printf("\nSeleccionado:\nScript: %s\nDescripción: %s\nEjemplo de ejecución: ./%s\n", parts[0], parts[1], parts[0])
}