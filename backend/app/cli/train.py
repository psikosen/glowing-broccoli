#!/usr/bin/env python3
"""
CLI tool for training the model
Usage: python -m app.cli.train --epochs 50
"""

import asyncio
import argparse
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import AsyncSessionLocal, init_db
from app.ml.training import train_model


async def main(epochs: int):
    """Main training function"""
    print("=" * 60)
    print("Dear More - Model Training")
    print("=" * 60)

    # Initialize database
    await init_db()

    # Create database session
    async with AsyncSessionLocal() as db:
        try:
            result = await train_model(db, epochs=epochs)

            print("\n" + "=" * 60)
            print("Training Summary")
            print("=" * 60)
            print(f"Model Version: {result['version']}")
            print(f"Model Path: {result['model_path']}")
            print(f"TFLite Path: {result['tflite_path']}")
            print(f"Final Loss: {result['final_loss']:.4f}")
            print("=" * 60)

        except Exception as e:
            print(f"\nError during training: {e}")
            raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Train the Dear More feature extractor model")
    parser.add_argument(
        "--epochs",
        type=int,
        default=50,
        help="Number of training epochs (default: 50)"
    )

    args = parser.parse_args()

    asyncio.run(main(args.epochs))
