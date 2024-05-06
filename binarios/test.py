import numpy as np
import matplotlib.pyplot as plt

# Define the function h(x) = log(x) - 6
def h(x):
    return np.log(x) - 6

# Generate x values from a small positive number close to zero to 10
x_values = np.linspace(0.01, 10, 400)

# Compute y values using the function h(x)
y_values = h(x_values)

# Create the plot
plt.figure(figsize=(8, 6))
plt.plot(x_values, y_values, label='h(x) = log(x) - 6', color='blue')

# Plot the vertical asymptote at x = 0
plt.axvline(x=0, color='red', linestyle='--', label='Asymptote at x = 0')

# Adding title and labels
plt.title('Graph of h(x) = log(x) - 6')
plt.xlabel('x')
plt.ylabel('h(x)')

# Setting the range for y-axis to better display the vertical shift
plt.ylim(-15, 5)

# Add a legend
plt.legend()

# Show the grid
plt.grid(True)

# Display the plot
plt.show()
