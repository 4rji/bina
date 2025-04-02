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

// getRepresentativeIP returns a target IP for the subnet (assumes /24 and uses .1 as gateway)
func getRepresentativeIP(subnet string) string {
	parts := strings.Split(subnet, "/")
	ip := parts[0]
	octets := strings.Split(ip, ".")
	if len(octets) != 4 {
		return ip
	}
	octets[3] = "1"
	return strings.Join(octets, ".")
}

func scanNetwork(subnet string, color string, wg *sync.WaitGroup, results chan<- string) {
	defer wg.Done()

	target := getRepresentativeIP(subnet)
	cmd := exec.Command("ping", "-c", "1", "-W", "1", target)
	err := cmd.Run()

	var result string
	if err == nil {
		result = fmt.Sprintf("%sSubnet %s: Access active%s\n", color, subnet, reset)
	} else {
		result = ""
	}

	if result != "" {
		result = "\n" + result + "\n-------------------\n"
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
		fmt.Println("\033[31mexport AllowedIPs=192.168.X.0/10.0.X.0/24 -like wireguard\033[0m")
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
		go scanNetwork(strings.TrimSpace(subnet), color, &wg, results)
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
