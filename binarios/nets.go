package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"
	"sync"
)

var colors = []string{
	"\033[31m", // red
	"\033[32m", // green
	"\033[33m", // yellow
	"\033[34m", // blue
	"\033[35m", // magenta
	"\033[36m", // cyan
	"\033[91m", // bright red
	"\033[92m", // bright green
	"\033[93m", // bright yellow
	"\033[94m", // bright blue
	"\033[95m", // bright magenta
}

const reset = "\033[0m"

// detectOS ejecuta nmap para detectar el sistema operativo del host y devuelve la salida en minúsculas.
func detectOS(ip string) string {
	cmd := exec.Command("nmap", "-O", "-Pn", ip)
	output, err := cmd.CombinedOutput()
	outStr := strings.ToLower(string(output))
	if err != nil {
		return "unknown"
	}
	return outStr
}

// getIconForOS asigna un icono según el contenido del string obtenido de detectOS.
func getIconForOS(osString string) string {
	if strings.Contains(osString, "windows") {
		return "🪟"
	} else if strings.Contains(osString, "darwin") || strings.Contains(osString, "macos") {
		return "🍎"
	} else if strings.Contains(osString, "redhat") {
		return "🎩"
	} else if strings.Contains(osString, "ubuntu") {
		return "🐧"
	} else if strings.Contains(osString, "debian") {
		return "🐧"
	} else if strings.Contains(osString, "linux") {
		return "🐧"
	}
	return "●"
}

// scanSubnet recorre las IPs de .1 a .254 de un /24, hace ping a cada una y si responde, detecta el OS y asigna un icono.
func scanSubnet(subnet string, color string, wg *sync.WaitGroup, results chan<- string) {
	defer wg.Done()

	parts := strings.Split(subnet, "/")
	ip := parts[0]
	octets := strings.Split(ip, ".")
	if len(octets) != 4 {
		results <- ""
		return
	}
	base := fmt.Sprintf("%s.%s.%s.", octets[0], octets[1], octets[2])
	var hostWg sync.WaitGroup
	var mu sync.Mutex
	activeHosts := []string{}

	// Recorre desde .1 hasta .254
	for i := 1; i < 255; i++ {
		hostIP := base + fmt.Sprintf("%d", i)
		hostWg.Add(1)
		go func(ip string) {
			defer hostWg.Done()
			cmd := exec.Command("ping", "-c", "1", "-W", "1", ip)
			if err := cmd.Run(); err == nil {
				// Si responde, detecta el OS y asigna el icono
				osStr := detectOS(ip)
				icon := getIconForOS(osStr)
				mu.Lock()
				activeHosts = append(activeHosts, fmt.Sprintf("%s %s", icon, ip))
				mu.Unlock()
			}
		}(hostIP)
	}
	hostWg.Wait()

	var result string
	if len(activeHosts) > 0 {
		result += fmt.Sprintf("\nSubnet %s:\n", subnet)
		for _, host := range activeHosts {
			result += fmt.Sprintf("  %s%s%s\n", color, host, reset)
		}
		result += "-------------------\n"
	}
	results <- result
}

func main() {
	allowedIPs := os.Getenv("AllowedIPs")
	if allowedIPs == "" {
		fmt.Println("")
		fmt.Println("\033[31mAllowedIPs environment variable not found.\033[0m")
		fmt.Println("\033[31mPlease set EXPORT=AllowedIPS as follows:\033[0m")
		fmt.Println("")
		fmt.Println("\033[31mexport AllowedIPs=192.168.X.0/24,10.0.X.0/24 -like wireguard\033[0m")
		return
	}

	subnets := strings.Split(allowedIPs, ",")
	var wg sync.WaitGroup
	results := make(chan string, len(subnets))

	fmt.Println("")
	fmt.Println("------------------- Scan Start -------------------")
	fmt.Println("")

	for i, subnet := range subnets {
		wg.Add(1)
		color := colors[i%len(colors)]
		go scanSubnet(strings.TrimSpace(subnet), color, &wg, results)
	}

	go func() {
		wg.Wait()
		close(results)
	}()

	for result := range results {
		if result != "" {
			fmt.Print(result)
		}
	}

	fmt.Println("")
	fmt.Println("------------------- Scan End -------------------")
	fmt.Println("")
	fmt.Println("\033[32mScan complete.\033[0m")
}
