package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"time"

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
	
	// Bright colors
	BrightRed    = "\033[91m"
	BrightGreen  = "\033[92m"
	BrightYellow = "\033[93m"
	BrightBlue   = "\033[94m"
	BrightPurple = "\033[95m"
	BrightCyan   = "\033[96m"
	BrightWhite  = "\033[97m"
	
	// Background colors
	BgRed     = "\033[41m"
	BgGreen   = "\033[42m"
	BgYellow  = "\033[43m"
	BgBlue    = "\033[44m"
	BgPurple  = "\033[45m"
	BgCyan    = "\033[46m"
	BgWhite   = "\033[47m"
	
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
	"net":     "🌐",
	"system":  "🖥️",
	"file":    "📁",
	"user":    "👤",
	"config":  "⚙️",
	"default": "▶️",
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
	file, err := os.Open("/opt/4rji/bin/descriptions.json")
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var descriptions Descriptions
	decoder := json.NewDecoder(file)
	if err := decoder.Decode(&descriptions); err != nil {
		return nil, err
	}

	return descriptions, nil
}

func parseReadme(filename string) ([]Script, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	var scripts []Script
	scanner := bufio.NewScanner(file)
	reCategory := regexp.MustCompile(`^#+\s*.*`)
	for scanner.Scan() {
		line := scanner.Text()
		if !reCategory.MatchString(line) && strings.TrimSpace(line) != "" {
			parts := strings.Fields(line)
			if len(parts) > 0 {
				script := parts[0]
				desc := ""
				if len(parts) > 1 {
					desc = strings.Join(parts[1:], " ")
				}
				scripts = append(scripts, Script{Name: script, Desc: desc})
			}
		}
	}
	return scripts, scanner.Err()
}

func printSeparator() {
	colors := []string{BrightRed, BrightYellow, BrightGreen, BrightCyan, BrightBlue, BrightPurple}
	width := 80
	segmentWidth := width / len(colors)
	
	for i, color := range colors {
		fmt.Print(color + strings.Repeat("═", segmentWidth))
	}
	fmt.Println(ColorReset)
}

func formatScriptList(scripts []Script) []string {
	var choices []string
	maxNameLength := 0
	
	// Find the longest script name
	for _, s := range scripts {
		if len(s.Name) > maxNameLength {
			maxNameLength = len(s.Name)
		}
	}
	
	// Add padding for icons and formatting
	maxNameLength += 4
	
	for _, s := range scripts {
		// Determine script type and icon
		icon := scriptIcons["default"]
		for scriptType, scriptIcon := range scriptIcons {
			if strings.Contains(strings.ToLower(s.Name), scriptType) {
				icon = scriptIcon
				break
			}
		}
		
		// Format the script entry with icon and colors
		padding := strings.Repeat(" ", maxNameLength-len(s.Name))
		formattedName := fmt.Sprintf("%s %s%s%s%s", 
			icon,
			BrightCyan,
			s.Name,
			ColorReset,
			padding,
		)
		
		// Add description with a different color
		description := fmt.Sprintf("%s%s%s%s", 
			Dim,
			BrightWhite,
			s.Desc,
			ColorReset,
		)
		
		// Combine name and description
		choices = append(choices, fmt.Sprintf("%s │ %s", formattedName, description))
	}
	
	return choices
}

func getScriptName(selectedScript string) string {
	cleanSelected := strings.ReplaceAll(selectedScript, ColorRed, "")
	cleanSelected = strings.ReplaceAll(cleanSelected, ColorReset, "")
	parts := strings.SplitN(cleanSelected, " | ", 2)
	if len(parts) < 2 {
		return ""
	}
	return strings.TrimSpace(parts[0])
}

// Función showImage corregida: usa "chafa" para mostrar imágenes.
func showImage(scriptName string) bool {
	imgPath := fmt.Sprintf("/opt/4rji/img-bin/%s", scriptName)
	
	// Try WebP first
	if _, err := os.Stat(imgPath + ".webp"); err == nil {
		cmd := exec.Command("chafa", "--size", "80x40", imgPath+".webp")
		output, err := cmd.CombinedOutput()
		if err != nil {
			fmt.Printf("%sError displaying image: %v%s\n", ColorRed, err, ColorReset)
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
			fmt.Printf("%sError displaying image: %v%s\n", ColorRed, err, ColorReset)
			return false
		}
		fmt.Printf("%s%s%s\n", ColorCyan, string(output), ColorReset)
		return true
	}

	return false
}

func showDetailedDescription(scriptName string, descriptions Descriptions) {
	if desc, ok := descriptions[scriptName]; ok {
		// Determine script type and icon
		icon := scriptIcons["default"]
		for scriptType, scriptIcon := range scriptIcons {
			if strings.Contains(strings.ToLower(scriptName), scriptType) {
				icon = scriptIcon
				break
			}
		}
		
		// Print header box
		width := 80
		fmt.Printf("\n%s%s%s%s%s\n", BrightPurple, BoxTopLeft, strings.Repeat(BoxHorizontal, width-2), BoxTopRight, ColorReset)
		
		// Print script name with icon
		nameRow := fmt.Sprintf(" %s  %s%s%s", icon, Bold, scriptName, ColorReset)
		fmt.Printf("%s%s%s%s%s%s\n", 
			BrightPurple,
			BoxVertical,
			nameRow,
			strings.Repeat(" ", width-3-len(scriptName)-3),
			BoxVertical,
			ColorReset,
		)
		
		// Print separator
		fmt.Printf("%s%s%s%s%s\n",
			BrightPurple,
			BoxVertical,
			strings.Repeat("─", width-2),
			BoxVertical,
			ColorReset,
		)
		
		// Print short description
		shortDescRow := fmt.Sprintf(" %s%s%s", BrightYellow, desc.ShortDesc, ColorReset)
		fmt.Printf("%s%s%s%s%s%s\n",
			BrightPurple,
			BoxVertical,
			shortDescRow,
			strings.Repeat(" ", width-3-len(desc.ShortDesc)),
			BoxVertical,
			ColorReset,
		)
		
		// Print separator
		fmt.Printf("%s%s%s%s%s\n",
			BrightPurple,
			BoxVertical,
			strings.Repeat("─", width-2),
			BoxVertical,
			ColorReset,
		)
		
		// Print detailed description with word wrap
		words := strings.Fields(desc.DetailedDesc)
		line := " "
		lineWidth := width - 4
		
		for _, word := range words {
			if len(line)+len(word)+1 > lineWidth {
				// Print current line
				fmt.Printf("%s%s %s%s%s%s%s\n",
					BrightPurple,
					BoxVertical,
					BrightWhite,
					line,
					strings.Repeat(" ", lineWidth-len(line)),
					BoxVertical,
					ColorReset,
				)
				line = " " + word
			} else {
				line += " " + word
			}
		}
		
		// Print last line if not empty
		if line != " " {
			fmt.Printf("%s%s %s%s%s%s%s\n",
				BrightPurple,
				BoxVertical,
				BrightWhite,
				line,
				strings.Repeat(" ", lineWidth-len(line)),
				BoxVertical,
				ColorReset,
			)
		}
		
		// Print bottom border
		fmt.Printf("%s%s%s%s%s\n",
			BrightPurple,
			BoxBottomLeft,
			strings.Repeat(BoxHorizontal, width-2),
			BoxBottomRight,
			ColorReset,
		)
	} else {
		// Show image if available
		if !showImage(scriptName) {
			fmt.Printf("\n%s%s No detailed description available for this script.%s\n",
				BrightYellow,
				"ℹ️",
				ColorReset,
			)
		}
	}
}

// New function to show loading animation
func showLoadingAnimation(duration time.Duration, message string) {
	spinChars := []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
	startTime := time.Now()
	
	for time.Since(startTime) < duration {
		for _, char := range spinChars {
			fmt.Printf("\r%s%s %s%s %s", BrightCyan, char, Bold, message, ColorReset)
			time.Sleep(80 * time.Millisecond)
		}
	}
	fmt.Println()
}

// New function to print fancy box
func printFancyBox(title string, content string) {
	width := 60
	fmt.Printf("%s%s%s%s%s\n", BrightCyan, BoxTopLeft, strings.Repeat(BoxHorizontal, width-2), BoxTopRight, ColorReset)
	fmt.Printf("%s%s %s%s%s%s%s%s\n", BrightCyan, BoxVertical, BrightPurple, Bold, title, ColorReset, strings.Repeat(" ", width-3-len(title)), BoxVertical)
	fmt.Printf("%s%s%s%s%s\n", BrightCyan, BoxBottomLeft, strings.Repeat(BoxHorizontal, width-2), BoxBottomRight, ColorReset)
	fmt.Println(content)
}

func main() {
	// Clear screen
	fmt.Print("\033[H\033[2J")
	
	// Show welcome animation
	showLoadingAnimation(1*time.Second, "Loading scripts...")
	
	// ASCII Art Header
	header := `
   ____            _       __      ____      __           __            
  / __/______ ____(_)___  / /_    / __/___  / /__ _____  / /____  _____
 _\ \/ __/ _ '/ __/ / __/ / __/   _\ \/ _ \/ / -_) __/ / __/ _ \/ __/
/___/\__/\_,_/_/ /_/\__/ /\__/   /___/\___/_/\__/_/    \__/\___/_/    
`
	fmt.Printf("%s%s%s\n", BrightCyan, header, ColorReset)
	
	descriptions, err := loadDescriptions()
	if err != nil {
		fmt.Printf("%sWarning: Could not load descriptions file: %v%s\n", ColorYellow, err, ColorReset)
	}

	scripts, err := parseReadme("/opt/4rji/bin/README.md")
	if err != nil {
		fmt.Printf("%sError reading README.md: %v%s\n", BrightRed, err, ColorReset)
		return
	}

	if len(scripts) == 0 {
		fmt.Printf("%sNo scripts found in README%s\n", BrightYellow, ColorReset)
		return
	}

	if len(os.Args) > 1 {
		searchTerm := strings.Join(os.Args[1:], " ")
		var filteredScripts []Script
		for _, s := range scripts {
			if strings.Contains(strings.ToLower(s.Name), strings.ToLower(searchTerm)) || strings.Contains(strings.ToLower(s.Desc), strings.ToLower(searchTerm)) {
				filteredScripts = append(filteredScripts, s)
			}
		}
		if len(filteredScripts) == 0 {
			fmt.Printf("%sNo se encontró ningún script que coincida con '%s'%s\n", ColorYellow, searchTerm, ColorReset)
			return
		} else if len(filteredScripts) == 1 {
			showDetailedDescription(filteredScripts[0].Name, descriptions)
			fmt.Printf("%sPress Enter to exit...%s", ColorBlue, ColorReset)
			reader := bufio.NewReader(os.Stdin)
			_, _ = reader.ReadString('\n')
			return
		} else {
			scripts = filteredScripts
		}
	}

	scriptChoices := formatScriptList(scripts)

	for {
		printSeparator()
		printFancyBox("Script Selector", "Choose a script from the list below:")
		
		var selectedScript string
		promptScript := &survey.Select{
			Message: fmt.Sprintf("%s%s%s Search:%s", Bold, BrightCyan, "🔍", ColorReset),
			Options: scriptChoices,
			PageSize: 15,
		}
		
		err = survey.AskOne(promptScript, &selectedScript, 
			survey.WithFilter(func(filter string, value string, index int) bool {
				cleanValue := strings.ReplaceAll(value, ColorRed, "")
				cleanValue = strings.ReplaceAll(cleanValue, ColorReset, "")
				cleanValue = strings.ReplaceAll(cleanValue, " | ", " ")
				return strings.Contains(strings.ToLower(cleanValue), strings.ToLower(filter))
			}),
			survey.WithIcons(func(icons *survey.IconSet) {
				icons.SelectFocus.Format = "🟢"
				icons.MarkedOption.Format = "✓"
				icons.UnmarkedOption.Format = "○"
			}),
			survey.WithStdio(os.Stdin, os.Stdout, os.Stderr),
		)

		if err != nil {
			fmt.Printf("%sError selecting script: %v%s\n", BrightRed, err, ColorReset)
			return
		}

		scriptName := getScriptName(selectedScript)
		if scriptName == "" {
			fmt.Printf("%sInvalid selection%s\n", BrightRed, ColorReset)
			continue
		}

		// Show script details with animation
		showLoadingAnimation(500*time.Millisecond, "Loading script details...")
		showDetailedDescription(scriptName, descriptions)
		
		printSeparator()
		fmt.Printf("%s%s Press Enter to return...%s", BrightCyan, "↩", ColorReset)
		reader := bufio.NewReader(os.Stdin)
		_, _ = reader.ReadString('\n')

		// Clear screen and return to menu
		fmt.Print("\033[H\033[2J")
	}
}
