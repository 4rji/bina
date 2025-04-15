package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strings"

	"github.com/AlecAivazis/survey/v2"
)

// ANSI color and style definitions
const (
	// Basic colors
	ColorReset  = "\033[0m"
	ColorRed    = "\033[31m"
	ColorGreen  = "\033[32m"
	ColorYellow = "\033[33m"
	ColorBlue   = "\033[34m"
	ColorPurple = "\033[35m"
	ColorCyan   = "\033[36m"
	ColorWhite  = "\033[37m"
	
	// Theme colors (matching the image)
	ThemeBlue    = "\033[38;5;33m"    // Bright blue for the top bar
	ThemeCyan    = "\033[38;5;43m"    // Cyan for the path
	ThemeYellow  = "\033[48;5;226m\033[38;5;0m"  // Yellow background with black text
	ThemeGreen   = "\033[38;5;46m"    // Bright green for commands
	
	// Text effects
	Bold      = "\033[1m"
	Dim       = "\033[2m"
	Italic    = "\033[3m"
	Underline = "\033[4m"
	Blink     = "\033[5m"
	Reverse   = "\033[7m"
)

// Box drawing characters
const (
	BoxTopLeft     = "╔"
	BoxTopRight    = "╗"
	BoxBottomLeft  = "╚"
	BoxBottomRight = "╝"
	BoxHorizontal  = "═"
	BoxVertical    = "║"
)

// Icons for different script types
var scriptIcons = map[string]string{
	"net":     "•",
	"system":  "•",
	"file":    "•",
	"user":    "•",
	"config":  "•",
	"default": "•",
}

type Script struct {
	Name string
	Desc string
}

type DetailedDescription struct {
	Name         string `json:"name"`
	ShortDesc    string `json:"short_desc"`
	DetailedDesc string `json:"detailed_desc"`
}

type Descriptions map[string]DetailedDescription

func loadDescriptions() (Descriptions, error) {
	fmt.Printf("%sLoading descriptions.json...%s\n", ColorCyan, ColorReset)
	file, err := os.Open("/opt/4rji/bin/descriptions.json")
	if err != nil {
		return nil, fmt.Errorf("error opening descriptions.json: %v", err)
	}
	defer file.Close()

	var descriptions Descriptions
	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&descriptions); err != nil {
		return nil, fmt.Errorf("error decoding descriptions.json: %v", err)
	}

	fmt.Printf("%sLoaded %d descriptions%s\n", ColorGreen, len(descriptions), ColorReset)
	for name := range descriptions {
		fmt.Printf("%sFound description for: %s%s\n", ColorGreen, name, ColorReset)
	}
	return descriptions, nil
}

func parseReadme(filename string) ([]Script, error) {
	fmt.Printf("%sLoading /opt/4rji/bin/README.md...%s\n", ColorCyan, ColorReset)
	file, err := os.Open("/opt/4rji/bin/README.md")
	if err != nil {
		return nil, fmt.Errorf("error opening README.md: %v", err)
	}
	defer file.Close()

	var scripts []Script
	scanner := bufio.NewScanner(file)
	reCategory := regexp.MustCompile(`^#+\s*.*`)
	seenScripts := make(map[string]bool)
	
	for scanner.Scan() {
		line := scanner.Text()
		if !reCategory.MatchString(line) && strings.TrimSpace(line) != "" {
			parts := strings.Fields(line)
			if len(parts) > 0 {
				script := parts[0]
				// Skip if we've already seen this script
				if seenScripts[script] {
					continue
				}
				seenScripts[script] = true
				
				desc := ""
				if len(parts) > 1 {
					desc = strings.Join(parts[1:], " ")
				}
				scripts = append(scripts, Script{Name: script, Desc: desc})
			}
		}
	}
	
	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error scanning README.md: %v", err)
	}
	
	fmt.Printf("%sLoaded %d scripts from README%s\n", ColorGreen, len(scripts), ColorReset)
	return scripts, nil
}

func printSeparator() {
	colors := []string{ColorRed, ColorBlue}
	width := 80
	segmentWidth := width / len(colors)
	
	for _, color := range colors {
		fmt.Print(Dim + color + strings.Repeat("═", segmentWidth))
	}
	fmt.Println(ColorReset)
}

func formatScriptList(scripts []Script) []string {
	var choices []string
	maxNameLength := 0
	
	for _, s := range scripts {
		if len(s.Name) > maxNameLength {
			maxNameLength = len(s.Name)
		}
	}
	
	maxNameLength += 2  // Reduced padding since we're using simpler format
	
	for _, s := range scripts {
		padding := strings.Repeat(" ", maxNameLength-len(s.Name))
		formattedName := fmt.Sprintf("%s%s%s%s", 
			ThemeCyan,
			s.Name,
			ColorReset,
			padding,
		)
		
		description := fmt.Sprintf("%s%s%s%s", 
			Dim,
			ThemeBlue,
			s.Desc,
			ColorReset,
		)
		
		choices = append(choices, fmt.Sprintf("%s · %s", formattedName, description))
	}
	
	return choices
}

func getScriptName(selectedScript string) string {
	// Remove all color codes first
	cleanSelected := strings.ReplaceAll(selectedScript, ColorRed, "")
	cleanSelected = strings.ReplaceAll(cleanSelected, ColorReset, "")
	cleanSelected = strings.ReplaceAll(cleanSelected, ThemeCyan, "")
	cleanSelected = strings.ReplaceAll(cleanSelected, ThemeBlue, "")
	cleanSelected = strings.ReplaceAll(cleanSelected, Bold, "")
	cleanSelected = strings.ReplaceAll(cleanSelected, Dim, "")
	
	// Split by the dot separator
	parts := strings.SplitN(cleanSelected, "·", 2)
	if len(parts) < 2 {
		return ""
	}
	
	// Get the first part and trim spaces
	scriptName := strings.TrimSpace(parts[0])
	fmt.Printf("%sExtracted script name: '%s'%s\n", ColorCyan, scriptName, ColorReset)
	return scriptName
}

// Función showImage corregida: usa "chafa" para mostrar imágenes.
func showImage(scriptName string) bool {
	imgPath := fmt.Sprintf("/opt/4rji/img-bin/%s", scriptName)
	
	// Try WebP first
	if _, err := os.Stat(imgPath + ".webp"); err == nil {
		cmd := exec.Command("chafa", "--size", "80x40", imgPath+".webp")
		output, err := cmd.CombinedOutput()
		if err != nil {
			return false
		}
		fmt.Printf("%s%s%s\n", ColorCyan, string(output), ColorReset)
		return true
	}

	// Try PNG if WebP doesn't exist
	if _, err := os.Stat(imgPath + ".png"); err == nil {
		cmd := exec.Command("chafa", "--size", "80x40", imgPath+".png")
		output, err := cmd.CombinedOutput()
		if err != nil {
			return false
		}
		fmt.Printf("%s%s%s\n", ColorCyan, string(output), ColorReset)
		return true
	}

	return false
}

func showDetailedDescription(scriptName string, descriptions Descriptions, scripts []Script) {
	// Clear screen and reset cursor position
	fmt.Print("\033[H\033[2J\033[3J")
	
	// Move cursor to top of screen
	fmt.Print("\033[H")
	
	// Show README description if available
	for _, script := range scripts {
		if script.Name == scriptName {
			// Center the script name
			width := 80
			padding := (width - len(scriptName)) / 2
			centeredName := strings.Repeat(" ", padding) + scriptName
			
			fmt.Printf("%s", Dim)
			printSeparator()
			fmt.Printf("%s", ColorReset)
			fmt.Printf("%s%s%s\n", ColorCyan, centeredName, ColorReset)
			fmt.Printf("%s%s%s\n", ColorWhite, script.Desc, ColorReset)
			break
		}
	}

	// Show detailed description from descriptions.json
	if desc, ok := descriptions[scriptName]; ok {
		fmt.Printf("%s", Dim)
		printSeparator()
		fmt.Printf("%s", ColorReset)
		fmt.Printf("\n%sScript:%s %s%s%s\n", ColorYellow, ColorReset, ColorRed, scriptName, ColorReset)
		fmt.Printf("%sShort description:%s %s%s%s\n", ColorYellow, ColorReset, ColorWhite, desc.ShortDesc, ColorReset)
		fmt.Printf("\n%sDetailed description:%s\n%s%s%s\n", ColorYellow, ColorReset, ColorWhite, desc.DetailedDesc, ColorReset)
	}
	
	// Show image only if it exists
	fmt.Print("\n\n\n")
	fmt.Printf("%s", Dim)
	printSeparator()
	fmt.Printf("%s", ColorReset)
	if showImage(scriptName) {
		fmt.Print("")
		fmt.Printf("%s", ThemeBlue)
		
		fmt.Printf("%s", ColorReset)
	}
}

// New function to print fancy box
func printFancyBox(title string, content string) {
	width := 60
	fmt.Printf("%s%s%s%s%s\n", ThemeBlue, BoxTopLeft, strings.Repeat(BoxHorizontal, width-2), BoxTopRight, ColorReset)
	fmt.Printf("%s%s %s%s%s%s%s%s\n", ThemeBlue, BoxVertical, ThemeCyan, Bold, title, ColorReset, strings.Repeat(" ", width-3-len(title)), BoxVertical)
	fmt.Printf("%s%s%s%s%s\n", ThemeBlue, BoxBottomLeft, strings.Repeat(BoxHorizontal, width-2), BoxBottomRight, ColorReset)
	fmt.Println(content)
}

// Add this function before main()
func copyToClipboard(text string) error {
	cmd := exec.Command("pbcopy")
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return err
	}

	if err := cmd.Start(); err != nil {
		return err
	}

	if _, err := stdin.Write([]byte(text)); err != nil {
		return err
	}

	if err := stdin.Close(); err != nil {
		return err
	}

	return cmd.Wait()
}

// Devuelve la lista combinada de scripts del README y ejecutables de /opt/4rji/bin
func getCombinedScripts(readmePath, binDir string) ([]Script, error) {
	// 1. Scripts del README
	readmeScripts, err := parseReadme(readmePath)
	if err != nil {
		return nil, err
	}
	readmeMap := make(map[string]bool)
	for _, s := range readmeScripts {
		readmeMap[s.Name] = true
	}

	// 2. Ejecutables en /opt/4rji/bin
	entries, err := os.ReadDir(binDir)
	if err != nil {
		return readmeScripts, nil // Si falla, solo los del README
	}
	var extraScripts []Script
	for _, entry := range entries {
		if entry.IsDir() { continue }
		name := entry.Name()
		if readmeMap[name] { continue }
		// Opcional: solo archivos ejecutables
		info, err := entry.Info()
		if err != nil { continue }
		mode := info.Mode()
		if mode&0111 == 0 { continue } // No es ejecutable
		extraScripts = append(extraScripts, Script{
			Name: name,
			Desc: "Script no documentado",
		})
	}

	// 3. Mezclar listas
	allScripts := append(readmeScripts, extraScripts...)
	return allScripts, nil
}

func main() {
	// Clear screen
	fmt.Print("\033[H\033[2J")
	
	fmt.Printf("%sStarting program...%s\n", ColorCyan, ColorReset)
	
	descriptions, err := loadDescriptions()
	if err != nil {
		fmt.Printf("%sError reading descriptions.json: %v%s\n", ColorRed, err, ColorReset)
	}

	scripts, err := getCombinedScripts("/opt/4rji/bin/README.md", "/opt/4rji/bin")
	if err != nil {
		fmt.Printf("%sError reading scripts: %v%s\n", ColorRed, err, ColorReset)
		return
	}

	if len(scripts) == 0 {
		fmt.Printf("%sNo scripts found in README or bin directory%s\n", ColorYellow, ColorReset)
		return
	}

	scriptChoices := formatScriptList(scripts)
	fmt.Printf("%sCreated %d script choices%s\n", ColorGreen, len(scriptChoices), ColorReset)

	// Sort script choices alphabetically
	sort.Slice(scriptChoices, func(i, j int) bool {
		// Remove color codes and formatting from both strings
		cleanA := strings.ReplaceAll(scriptChoices[i], ColorRed, "")
		cleanA = strings.ReplaceAll(cleanA, ColorReset, "")
		cleanA = strings.ReplaceAll(cleanA, ThemeCyan, "")
		cleanA = strings.ReplaceAll(cleanA, ThemeBlue, "")
		cleanA = strings.ReplaceAll(cleanA, Bold, "")
		cleanA = strings.ReplaceAll(cleanA, Dim, "")
		
		cleanB := strings.ReplaceAll(scriptChoices[j], ColorRed, "")
		cleanB = strings.ReplaceAll(cleanB, ColorReset, "")
		cleanB = strings.ReplaceAll(cleanB, ThemeCyan, "")
		cleanB = strings.ReplaceAll(cleanB, ThemeBlue, "")
		cleanB = strings.ReplaceAll(cleanB, Bold, "")
		cleanB = strings.ReplaceAll(cleanB, Dim, "")
		
		// Get script names
		partsA := strings.SplitN(cleanA, "·", 2)
		partsB := strings.SplitN(cleanB, "·", 2)
		
		if len(partsA) < 2 || len(partsB) < 2 {
			return false
		}
		
		nameA := strings.TrimSpace(partsA[0])
		nameB := strings.TrimSpace(partsB[0])
		
		// Sort alphabetically
		return strings.ToLower(nameA) < strings.ToLower(nameB)
	})

	// Get initial search term from command line arguments
	initialSearch := ""
	if len(os.Args) > 1 {
		initialSearch = strings.Join(os.Args[1:], " ")
	}

	for {
		// Clear screen at the start of each loop
		fmt.Print("\033[H\033[2J")
		
		// Show header only once
		header := fmt.Sprintf(`
%s╭─────────────────────────────────────────────╮%s
%s│%s %s4rji Script Selector%s                        %s│%s
%s╰─────────────────────────────────────────────╯%s
`, 
			ThemeBlue, ColorReset,
			ThemeBlue, ColorReset, Bold, ColorReset, ThemeBlue, ColorReset,
			ThemeBlue, ColorReset,
		)
		fmt.Print(header)
		
		printFancyBox("Available Scripts", "Choose a script from the list below:")
		
		var selectedScript string
		
		// Create a custom filter function
		filterFunc := func(filter string, value string, index int) bool {
			// Remove all color codes and formatting
			cleanValue := strings.ReplaceAll(value, ColorRed, "")
			cleanValue = strings.ReplaceAll(cleanValue, ColorReset, "")
			cleanValue = strings.ReplaceAll(cleanValue, ThemeCyan, "")
			cleanValue = strings.ReplaceAll(cleanValue, ThemeBlue, "")
			cleanValue = strings.ReplaceAll(cleanValue, Bold, "")
			cleanValue = strings.ReplaceAll(cleanValue, Dim, "")
			
			// Split by the dot separator to get script name and description
			parts := strings.SplitN(cleanValue, "·", 2)
			if len(parts) < 2 {
				return false
			}
			
			// Get the script name and trim spaces
			scriptName := strings.TrimSpace(parts[0])
			
			// Check if the filter matches the script name
			return strings.Contains(strings.ToLower(scriptName), strings.ToLower(filter))
		}
		
		promptScript := &survey.Select{
			Message: fmt.Sprintf("%s%s Search:%s", Bold, ThemeCyan, ColorReset),
			Options: scriptChoices,
			PageSize: 15,
			Filter: filterFunc,
		}
		
		// Set initial search term if provided
		if initialSearch != "" {
			promptScript.FilterMessage = initialSearch
			initialSearch = "" // Reset after first use
		}
		
		err = survey.AskOne(promptScript, &selectedScript, 
			survey.WithIcons(func(icons *survey.IconSet) {
				icons.SelectFocus.Format = ">"
				icons.MarkedOption.Format = "•"
				icons.UnmarkedOption.Format = " "
			}),
			survey.WithStdio(os.Stdin, os.Stdout, os.Stderr),
		)

		if err != nil {
			fmt.Printf("%sError selecting script: %v%s\n", ColorRed, err, ColorReset)
			return
		}

		fmt.Printf("%sSelected option: '%s'%s\n", ColorCyan, selectedScript, ColorReset)
		scriptName := getScriptName(selectedScript)
		if scriptName == "" {
			fmt.Printf("%sInvalid selection%s\n", ColorRed, ColorReset)
			continue
		}

		// Copy script name to clipboard
		if err := copyToClipboard(scriptName); err != nil {
			fmt.Printf("%sError copying to clipboard: %v%s\n", ColorRed, err, ColorReset)
		} else {
			fmt.Printf("%sScript name '%s' copied to clipboard!%s\n", ColorGreen, scriptName, ColorReset)
		}

		// Clear screen before showing details
		fmt.Print("\033[H\033[2J")
		showDetailedDescription(scriptName, descriptions, scripts)
		
		fmt.Printf("%s", Dim)
		
		fmt.Printf("%s", ColorReset)
		fmt.Printf("%s%s Press Enter to return...%s", ColorCyan, "↩", ColorReset)
		reader := bufio.NewReader(os.Stdin)
		_, _ = reader.ReadString('\n')
	}
}
