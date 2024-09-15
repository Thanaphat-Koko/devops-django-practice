from django.test import TestCase
from .models import Food
from datetime import datetime

class FoodModelTest(TestCase):

    def setUp(self):
        # Create a Food object for testing
        self.food = Food.objects.create(
            title="Pizza",
            price=150,
            special_price=100,
            is_premium=True,
            promotion_end_at=datetime(2024, 12, 31, 23, 59, 59),
            description="Delicious cheese pizza with extra toppings",
            image_relative_url="images/pizza.jpg"
        )

    def test_food_creation(self):
        # Ensure the Food object was created successfully
        food = self.food
        self.assertEqual(food.title, "Pizza")
        self.assertEqual(food.price, 150)
        self.assertEqual(food.special_price, 100)
        self.assertTrue(food.is_premium)
        self.assertEqual(food.promotion_end_at, datetime(2024, 12, 31, 23, 59, 59))
        self.assertEqual(food.description, "Delicious cheese pizza with extra toppings")
        self.assertEqual(food.image_relative_url, "images/pizza.jpg")

    def test_default_values(self):
        # Create another Food object to check default values
        food = Food.objects.create(
            title="Burger",
            price=80
        )
        self.assertIsNone(food.special_price)
        self.assertFalse(food.is_premium)
        self.assertIsNone(food.promotion_end_at)
        self.assertIsNone(food.description)
        self.assertIsNone(food.image_relative_url)

    def test_str_representation(self):
        # Test the string representation of the food object
        food = self.food
        self.assertEqual(str(food), "Pizza (id: {})".format(food.id))
