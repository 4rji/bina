import matplotlib.pyplot as plt
import numpy as np

# Circle equation parameters
h = 2  # x-coordinate of the center
k = 5  # y-coordinate of the center
r = 4  # radius

# Create an array of theta values for the circle
theta = np.linspace(0, 2*np.pi, 100)

# Parametric equations for the circle
x = h + r * np.cos(theta)
y = k + r * np.sin(theta)

# Plot the circle
plt.figure(figsize=(6,6))
plt.plot(x, y, color='blue')
plt.title('Graph of the Circle')
plt.xlabel('x')
plt.ylabel('y')
plt.grid(True)

# Plot the center of the circle
plt.scatter(h, k, color='red', label='Center (2, 5)')
plt.legend()

plt.gca().set_aspect('equal', adjustable='box')
plt.show()
