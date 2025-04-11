package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"regexp"
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
	file, err := os.Open("descriptions.json")
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
	fmt.Printf("%sLoading README.md...%s\n", ColorCyan, ColorReset)
	file, err := os.Open(filename)
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
				fmt.Printf("%sFound script in README: %s - %s%s\n", ColorGreen, script, desc, ColorReset)
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
	colors := []string{ThemeBlue, ThemeCyan}
	width := 80
	segmentWidth := width / len(colors)
	
	for _, color := range colors {
		fmt.Print(color + strings.Repeat("═", segmentWidth))
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
		fmt.Printf("%sFound WebP image at: %s%s\n", ColorGreen, imgPath+".webp", ColorReset)
		cmd := exec.Command("chafa", "--size", "80x40", imgPath+".webp")
		output, err := cmd.CombinedOutput()
		if err != nil {
			fmt.Printf("%sError displaying WebP image: %v%s\n", ColorRed, err, ColorReset)
			return false
		}
		fmt.Printf("%s%s%s\n", ColorCyan, string(output), ColorReset)
		return true
	}

	// Try PNG if WebP doesn't exist
	if _, err := os.Stat(imgPath + ".png"); err == nil {
		fmt.Printf("%sFound PNG image at: %s%s\n", ColorGreen, imgPath+".png", ColorReset)
		cmd := exec.Command("chafa", "--size", "80x40", imgPath+".png")
		output, err := cmd.CombinedOutput()
		if err != nil {
			fmt.Printf("%sError displaying PNG image: %v%s\n", ColorRed, err, ColorReset)
			return false
		}
		fmt.Printf("%s%s%s\n", ColorCyan, string(output), ColorReset)
		return true
	}

	fmt.Printf("%sNo image found at: %s%s\n", ColorYellow, imgPath, ColorReset)
	return false
}

func showDetailedDescription(scriptName string, descriptions Descriptions, scripts []Script) {
	width := 80
	boxWidth := width + 2

	// First show README description
	fmt.Printf("\n%s%s README Description %s%s\n", ThemeBlue, BoxTopLeft, strings.Repeat(BoxHorizontal, boxWidth-20), BoxTopRight)
	foundInReadme := false
	for _, script := range scripts {
		if script.Name == scriptName {
			foundInReadme = true
			fmt.Printf("%s%s %s%s%s%s%s\n", 
				ThemeBlue,
				BoxVertical,
				ThemeCyan,
				script.Desc,
				strings.Repeat(" ", boxWidth-3-len(script.Desc)),
				BoxVertical,
				ColorReset,
			)
			break
		}
	}
	if !foundInReadme {
		fmt.Printf("%s%s No description found in README %s%s\n", ThemeBlue, BoxVertical, strings.Repeat(" ", boxWidth-25), BoxVertical)
	}
	fmt.Printf("%s%s%s%s%s\n\n", ThemeBlue, BoxBottomLeft, strings.Repeat(BoxHorizontal, boxWidth-2), BoxBottomRight, ColorReset)

	// Then show descriptions.json content
	fmt.Printf("%s%s Detailed script description: %s%s\n", ThemeBlue, BoxTopLeft, strings.Repeat(BoxHorizontal, boxWidth-28), BoxTopRight)
	if desc, ok := descriptions[scriptName]; ok {
		// Print script name
		fmt.Printf("%s%s Script: %s%s%s%s%s\n", 
			ThemeBlue,
			BoxVertical,
			Bold,
			scriptName,
			strings.Repeat(" ", boxWidth-10-len(scriptName)),
			BoxVertical,
			ColorReset,
		)

		// Print short description
		fmt.Printf("%s%s Short description: %s%s%s%s%s\n", 
			ThemeBlue,
			BoxVertical,
			ThemeCyan,
			desc.ShortDesc,
			strings.Repeat(" ", boxWidth-19-len(desc.ShortDesc)),
			BoxVertical,
			ColorReset,
		)

		if desc.DetailedDesc != "" {
			// Print detailed description
			fmt.Printf("%s%s%s%s%s\n",
				ThemeBlue,
				BoxVertical,
				strings.Repeat("─", boxWidth-2),
				BoxVertical,
				ColorReset,
			)
			
			fmt.Printf("%s%s Detailed description:%s%s%s\n", 
				ThemeBlue,
				BoxVertical,
				strings.Repeat(" ", boxWidth-22),
				BoxVertical,
				ColorReset,
			)

			// Print detailed description with proper word wrapping
			words := strings.Fields(desc.DetailedDesc)
			line := ""
			lineWidth := boxWidth - 4
			
			for _, word := range words {
				if len(line)+len(word)+1 > lineWidth {
					fmt.Printf("%s%s %s%s%s%s%s\n",
						ThemeBlue,
						BoxVertical,
						ThemeCyan,
						line,
						strings.Repeat(" ", lineWidth-len(line)),
						BoxVertical,
						ColorReset,
					)
					line = word
				} else {
					if line == "" {
						line = word
					} else {
						line += " " + word
					}
				}
			}
			
			if line != "" {
				fmt.Printf("%s%s %s%s%s%s%s\n",
					ThemeBlue,
					BoxVertical,
					ThemeCyan,
					line,
					strings.Repeat(" ", lineWidth-len(line)),
					BoxVertical,
					ColorReset,
				)
			}
		}
	} else {
		fmt.Printf("%s%s No description found in descriptions.json %s%s\n", ThemeBlue, BoxVertical, strings.Repeat(" ", boxWidth-35), BoxVertical)
	}
	fmt.Printf("%s%s%s%s%s\n\n", ThemeBlue, BoxBottomLeft, strings.Repeat(BoxHorizontal, boxWidth-2), BoxBottomRight, ColorReset)

	// Finally show image
	fmt.Printf("%s%s Image %s%s\n", ThemeBlue, BoxTopLeft, strings.Repeat(BoxHorizontal, boxWidth-8), BoxTopRight)
	if !showImage(scriptName) {
		fmt.Printf("%s%s No image found %s%s\n", ThemeBlue, BoxVertical, strings.Repeat(" ", boxWidth-15), BoxVertical)
	}
	fmt.Printf("%s%s%s%s%s\n\n", ThemeBlue, BoxBottomLeft, strings.Repeat(BoxHorizontal, boxWidth-2), BoxBottomRight, ColorReset)
}

// New function to print fancy box
func printFancyBox(title string, content string) {
	width := 60
	fmt.Printf("%s%s%s%s%s\n", ThemeBlue, BoxTopLeft, strings.Repeat(BoxHorizontal, width-2), BoxTopRight, ColorReset)
	fmt.Printf("%s%s %s%s%s%s%s%s\n", ThemeBlue, BoxVertical, ThemeCyan, Bold, title, ColorReset, strings.Repeat(" ", width-3-len(title)), BoxVertical)
	fmt.Printf("%s%s%s%s%s\n", ThemeBlue, BoxBottomLeft, strings.Repeat(BoxHorizontal, width-2), BoxBottomRight, ColorReset)
	fmt.Println(content)
}

func main() {
	// Clear screen
	fmt.Print("\033[H\033[2J")
	
	fmt.Printf("%sStarting program...%s\n", ColorCyan, ColorReset)
	
	descriptions, err := loadDescriptions()
	if err != nil {
		fmt.Printf("%sError reading descriptions.json: %v%s\n", ColorRed, err, ColorReset)
	}

	scripts, err := parseReadme("README.md")
	if err != nil {
		fmt.Printf("%sError reading README.md: %v%s\n", ColorRed, err, ColorReset)
		return
	}

	if len(scripts) == 0 {
		fmt.Printf("%sNo scripts found in README%s\n", ColorYellow, ColorReset)
		return
	}

	scriptChoices := formatScriptList(scripts)
	fmt.Printf("%sCreated %d script choices%s\n", ColorGreen, len(scriptChoices), ColorReset)

	for {
		// Clear screen at the start of each loop
		fmt.Print("\033[H\033[2J")
		
		// Show header only in main menu
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
		
		printSeparator()
		printFancyBox("Available Scripts", "Choose a script from the list below:")
		
		var selectedScript string
		promptScript := &survey.Select{
			Message: fmt.Sprintf("%s%s Search:%s", Bold, ThemeCyan, ColorReset),
			Options: scriptChoices,
			PageSize: 15,
		}
		
		err = survey.AskOne(promptScript, &selectedScript, 
			survey.WithFilter(func(filter string, value string, index int) bool {
				cleanValue := strings.ReplaceAll(value, ColorRed, "")
				cleanValue = strings.ReplaceAll(cleanValue, ColorReset, "")
				cleanValue = strings.ReplaceAll(cleanValue, " · ", " ")
				return strings.Contains(strings.ToLower(cleanValue), strings.ToLower(filter))
			}),
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

		// Clear screen before showing details
		fmt.Print("\033[H\033[2J")
		showDetailedDescription(scriptName, descriptions, scripts)
		
		printSeparator()
		fmt.Printf("%s%s Press Enter to return...%s", ColorCyan, "↩", ColorReset)
		reader := bufio.NewReader(os.Stdin)
		_, _ = reader.ReadString('\n')
	}
}
