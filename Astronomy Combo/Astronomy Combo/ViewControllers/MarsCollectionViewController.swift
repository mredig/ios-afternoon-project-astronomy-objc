//
//  MarsCollectionViewController.swift
//  Astronomy Combo
//
//  Created by Michael Redig on 10/14/19.
//  Copyright © 2019 Red_Egg Productions. All rights reserved.
//

import UIKit

class MarsCollectionViewController: UICollectionViewController {

	lazy var roverController: RoverController = {
		let controller = RoverController(roverNamed: "Curiosity")
		controller.delegate = self
		return controller;
	}()

	override func viewDidLoad() {
		super.viewDidLoad()

		let half = (view.frame.width / 2) - 20
		let flowLayout = UICollectionViewFlowLayout()
		flowLayout.itemSize = CGSize(width: half, height: half)
		collectionView.collectionViewLayout = flowLayout
	}

	private func updateViews() {
		navigationItem.title = "\(roverController.currentRover ?? "") Sol \(roverController.currentSol)"
	}

	@IBAction func previousButtonPushed(_ sender: UIBarButtonItem) {
		roverController.previousSol()
	}

	@IBAction func nextButtonPushed(_ sender: UIBarButtonItem) {
		roverController.nextSol()
	}

	@IBAction func searchButtonPushed(_ sender: UIBarButtonItem) {
		let alertVC = UIAlertController(title: "Choose a Rover", message: nil, preferredStyle: .actionSheet)
		["Curiosity", "Spirit", "Opportunity"].forEach {
			alertVC.addAction(UIAlertAction(title: $0, style: .default, handler: roverSelectionChanged(_:)))
		}
		alertVC.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		present(alertVC, animated: true)
	}

	func roverSelectionChanged(_ action: UIAlertAction) {
		roverController.currentRover = action.title
	}

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let detailVC = segue.destination as? MarsDetailViewController {
			guard let indexPath = collectionView.indexPathsForSelectedItems?.first else { return }
			detailVC.roverController = roverController
			detailVC.photoURL = roverController.currentSolPhotos[indexPath.row]
		}
	}
}

extension MarsCollectionViewController: UICollectionViewDelegateFlowLayout {
	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return roverController.currentSolPhotos.count
	}

	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MarsCell", for: indexPath)
		guard let marsCell = cell as? MarsCollectionViewCell else { return cell }
		marsCell.roverController = roverController
		marsCell.photoURL = roverController.currentSolPhotos[indexPath.row]

		return marsCell
	}

	override func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
		guard let marsCell = cell as? MarsCollectionViewCell else { return }
		marsCell.cancelLoad()
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		let half = (view.frame.width / 2) - 20
		return CGSize(width: half, height: half)
	}
}

extension MarsCollectionViewController: RoverControllerDelegate {
	func roverControllerLoadedData(_ controller: RoverController) {
		DispatchQueue.main.async {
			self.collectionView.reloadData()
			self.updateViews()
		}
	}
}
